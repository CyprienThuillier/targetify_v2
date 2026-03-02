from django import forms
from django.contrib.auth.forms import UserCreationForm, AuthenticationForm
from .models import User

class RegisterForm(UserCreationForm):
    email = forms.EmailField(required=True)

    class Meta:
        model = User
        fields = ("username", "email", "password1", "password2")

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for field in self.fields.values():
            field.widget.attrs.update({"class": "w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-1 focus:ring-[#22C55E] focus:border-[#22C55E] text-sm"})

class LoginForm(AuthenticationForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for field in self.fields.values():
            field.widget.attrs.update({"class": "w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-1 focus:ring-[#22C55E] focus:border-[#22C55E] text-sm"})

class PasswordRecoveryForm(forms.Form):
    email = forms.EmailField(required=True, widget=forms.EmailInput(attrs={
        "class": "w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-1 focus:ring-[#22C55E] focus:border-[#22C55E] text-sm",
        "placeholder": "Enter your email address",
    }))