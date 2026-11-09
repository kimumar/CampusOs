import re
from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _

class CampusPasswordValidator:
    def validate(self, password, user=None):
        if not isinstance(password, str) or len(password) < 10 or not re.search(r"[A-Z]", password) or not re.search(r"[a-z]", password) or not re.search(r"[0-9]", password) or not re.search(r"[^A-Za-z0-9]", password):
            raise ValidationError(_("Password must contain at least 10 characters, uppercase and lowercase letters, a number, and a symbol."), code="password_complexity")
    def get_help_text(self):
        return _("At least 10 characters, uppercase and lowercase letters, a number, and a symbol.")
