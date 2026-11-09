"""One-time email verification tokens, separate from password reset."""
from django.contrib.auth.tokens import PasswordResetTokenGenerator


class EmailVerificationTokenGenerator(PasswordResetTokenGenerator):
    key_salt = "campusos.accounts.email_verification.v1"

    def _make_hash_value(self, user, timestamp):
        # Once verified, this token is invalid. Trial time is included so
        # later account-state changes cannot accidentally restore validity.
        return (
            f"{user.pk}{user.password}{timestamp}"
            f"{user.email}{user.email_verified}{user.trial_started_at}"
        )


email_verification_token = EmailVerificationTokenGenerator()
