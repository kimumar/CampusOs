from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import StudentUser, StudentProfile

class StudentProfileInline(admin.StackedInline):
    model = StudentProfile
    can_delete = False
    extra = 0

@admin.register(StudentUser)
class StudentUserAdmin(UserAdmin):
    model = StudentUser
    ordering = ("email",)
    list_display = ("email", "email_verified", "trial_started_at", "paid_until", "is_staff", "is_active")
    list_filter = ("email_verified", "is_staff", "is_active")
    search_fields = ("email",)
    readonly_fields = ("id", "last_login", "date_joined", "trial_started_at")
    fieldsets = ((None, {"fields": ("email", "password")}), ("Access", {"fields": ("email_verified", "trial_started_at", "paid_until", "is_active")}), ("Permissions", {"fields": ("is_staff", "is_superuser", "groups", "user_permissions")}), ("Audit", {"fields": ("id", "last_login", "date_joined")}))
    add_fieldsets = ((None, {"classes": ("wide",), "fields": ("email", "password1", "password2", "is_staff", "is_active")}),)
    inlines = (StudentProfileInline,)

@admin.register(StudentProfile)
class StudentProfileAdmin(admin.ModelAdmin):
    list_display = ("user", "preferred_name", "institution", "department", "level")
    search_fields = ("user__email", "preferred_name", "institution", "department")

from .models import AcademicRecord
@admin.register(AcademicRecord)
class AcademicRecordAdmin(admin.ModelAdmin):
    list_display = ("user", "kind", "record_id", "is_deleted", "modified_at")
    list_filter = ("kind", "is_deleted")
    search_fields = ("user__email", "record_id")
    readonly_fields = ("user", "kind", "record_id")
    def has_add_permission(self, request):
        return False
