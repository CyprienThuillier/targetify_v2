"""
Sync wrapper around the async Playwright scraper.
Called by the Celery task in jobs/tasks.py.
"""
import asyncio
import time
from .analyser import analyze
from .export import export_file

MAX_RETRIES = 3

def run_scrape(
    search_query: str,
    city: str,
    max_results: int,
    output_path: str,
    on_result=None,
    existing_urls: set = None,
    user=None,
):
    return asyncio.run(
        _run_async(search_query, city, max_results, output_path, on_result, existing_urls or set(), user)
    )

async def _run_async(search_query, city, max_results, output_path, on_result, existing_urls, user):
    from playwright.async_api import async_playwright
    import asyncio as aio

    all_urls = set()
    all_results = []
    init_time = int(time.time())

    async with async_playwright() as pw:
      browser = await pw.firefox.launch(headless=True)
      sem = aio.Semaphore(10)

      # Collect URLs (capped at max_results)
      page = await browser.new_page()
      query = f"{search_query} {city}".strip()
      await page.goto(f"https://www.google.com/maps/search/{query}")
      try:
        await page.get_by_role("button", name="Tout accepter").click(timeout=5000)
      except Exception:
        pass
      try:
        await page.get_by_role("button", name="Accept all").click(timeout=5000)
      except Exception:
        pass
      try:
        await page.get_by_role("button", name="Tout refuser").click(timeout=5000)
      except Exception:
        pass
      await page.wait_for_selector("a.hfpxzc", timeout=30000)
      feed = page.locator("div[role='feed']")
      previous = 0
      while len(all_urls) < max_results:
        await feed.evaluate("el => el.scrollTo(0, el.scrollHeight)")
        await page.wait_for_timeout(2000)
        items = page.locator("a.hfpxzc")
        count = await items.count()
        if count == previous:
          break
        previous = count
        for i in range(count):
          href = await items.nth(i).get_attribute("href")
          if href and href not in all_urls and href not in existing_urls:
            all_urls.add(href)
          if len(all_urls) >= max_results:
            break
      await page.close()

      new_urls = list(all_urls)[:max_results]
      print(f"[Scraper] Collected {len(new_urls)} new URLs")

      # Record URLs for deduplication
      if user:
        from jobs.models import SearchedUrl
        for url in new_urls:
          SearchedUrl.objects.get_or_create(user=user, url=url)

      # Analyse each URL
      tasks = [analyze(browser, url, MAX_RETRIES, sem, search_query) for url in new_urls]
      results = await aio.gather(*tasks)
      valid = [r for r in results if r is not None]

      export_file(valid, filename=output_path, append=True)
      if on_result:
        for r in valid:
          on_result(r)
      all_results.extend(valid)

      await browser.close()

    elapsed = int(time.time()) - init_time
    print(f"Done in {elapsed // 60:02d}m{elapsed % 60:02d}s — {len(all_results)} results")
    return all_results
