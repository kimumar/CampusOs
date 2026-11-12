from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from .models import StudentUser, StudentProfile

class RegistrationSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=10, trim_whitespace=False)
    referral_code = serializers.CharField(required=False, allow_blank=True, max_length=24)
    def validate_email(self, value):
        email = value.strip().lower()
        if StudentUser.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError("An account already exists with this email.")
        return email
    def validate_password(self, value):
        validate_password(value)
        return value
    def validate_referral_code(self, value):
        return value.strip().upper()

class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = StudentProfile
        fields = ["preferred_name", "institution_type", "institution", "department", "level", "pulse_opt_in"]
    def validate(self, attrs):
        for field in ("institution", "department", "level"):
            value = attrs.get(field, getattr(self.instance, field, "") if self.instance else "")
            if value and not str(value).strip():
                raise serializers.ValidationError({field:"Cannot contain only whitespace."})
        return attrs
