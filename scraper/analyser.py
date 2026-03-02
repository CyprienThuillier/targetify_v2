import random
import asyncio
from playwright.async_api import TimeoutError as PlaywrightTimeout

async def safe_get(locator, attribute=None, timeout=3000):
    try:
        if attribute:
            return await locator.get_attribute(attribute, timeout=timeout)
        return await locator.inner_text(timeout=timeout)
    except Exception:
        return None

async def analyze(browser, url: str, max_retries, sem, category) -> dict | None:
    async with sem:
        for attempt in range(1, max_retries + 1):
            page = await browser.new_page()
            try:
                await page.goto(url, timeout=15000, wait_until="domcontentloaded")
                try:
                    await page.get_by_role("button", name="Tout refuser").click(timeout=5000)
                    await page.wait_for_selector('[data-item-id]', timeout=10000)
                except Exception:
                    pass
                await page.wait_for_selector('[data-item-id]', timeout=10000)
                await asyncio.sleep(random.uniform(0.8, 1.5))

                name = await safe_get(page.locator("h1").first, timeout=5000)
                address_raw = await safe_get(page.locator('[data-item-id="address"]'), attribute="aria-label")
                address = address_raw.replace("Adresse\u00a0: ", "").strip() if address_raw else None
                website = await safe_get(page.locator('[data-item-id="authority"]'), attribute="aria-label")
                phone = await safe_get(
                    page.locator('[data-item-id^="phone"] div[class*="fontBody"]').first,
                    timeout=3000
                )
                lead_score = 0
                if not website:
                    lead_score += 40
                if not phone:
                    lead_score += 10

                await page.close()
                return {"url": url, "name": name, "category": category,
                        "address": address, "phone": phone, "website": website, "lead_score": lead_score}

            except (PlaywrightTimeout, Exception):
                await page.close()
                if attempt == max_retries:
                    return None
                await asyncio.sleep(random.uniform(1.0, 2.0))
