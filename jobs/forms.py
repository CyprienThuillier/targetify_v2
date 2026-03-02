from django import forms

class NewJobForm(forms.Form):
    search_query = forms.CharField(
        max_length=255,
        widget=forms.TextInput(attrs={
            "class": "w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-1 focus:ring-green-500 text-sm",
            "placeholder": 'e.g. "plumber", "dentist", "web agency"',
        })
    )
    city = forms.CharField(
        max_length=255,
        required=False,
        widget=forms.TextInput(attrs={
            "class": "w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-1 focus:ring-green-500 text-sm",
            "placeholder": 'e.g. "Paris", "London", "New York"',
        })
    )
    max_results = forms.ChoiceField(
        choices=[(10, "10 leads"), (25, "25 leads"), (50, "50 leads"), (100, "100 leads"), (200, "200 leads"), (500, "500 leads")],
        initial=50,
        widget=forms.Select(attrs={
            "class": "w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-1 focus:ring-green-500 text-sm bg-white",
        })
    )
