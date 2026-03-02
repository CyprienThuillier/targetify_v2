from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    """Extended user — add fields here as needed."""
    class Meta:
        db_table = "users"
