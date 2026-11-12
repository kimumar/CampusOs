from django.contrib import admin
admin.site.index_template = "admin/campusos_index.html"
admin.site.site_header = "CampusOS Administration"
admin.site.site_title = "CampusOS"
admin.site.index_title = "Manage CampusOS"
from django.contrib.auth.admin import UserAdmin
from .models import (StudentUser, StudentProfile, ReferralPartner, PartnerReferralCode,
                     ReferralAttribution, SubscriptionPayment, ReferralReward,
                     CampusBusinessSettings)
from .subscription_service import verify_recorded_payment

class StudentProfileInline(admin.StackedInline):
    model = StudentProfile
    can_delete = False
    extra = 0

@admin.register(StudentUser)
class StudentUserAdmin(UserAdmin):
    model = StudentUser
    ordering = ("email",)
    list_display = ("email", "email_verified", "trial_started_at", "paid_until", "complimentary_lifetime", "complimentary_until", "is_staff", "is_active")
    list_filter = ("email_verified", "is_staff", "is_active")
    search_fields = ("email",)
    readonly_fields = ("id", "last_login", "date_joined", "trial_started_at")
    fieldsets = ((None, {"fields": ("email", "password")}), ("Access", {"fields": ("email_verified", "trial_started_at", "trial_duration_days", "trial_expires_at", "paid_until", "complimentary_until", "complimentary_lifetime", "complimentary_reason", "is_active")}), ("Permissions", {"fields": ("is_staff", "is_superuser", "groups", "user_permissions")}), ("Audit", {"fields": ("id", "last_login", "date_joined")}))
    add_fieldsets = ((None, {"classes": ("wide",), "fields": ("email", "password1", "password2", "is_staff", "is_active")}),)
    inlines = (StudentProfileInline,)
    def get_readonly_fields(self, request, obj=None):
        base = tuple(super().get_readonly_fields(request, obj))
        if request.user.is_superuser:
            return base
        return base + ("email_verified", "trial_duration_days", "trial_expires_at",
                       "paid_until", "complimentary_until", "complimentary_lifetime",
                       "complimentary_reason", "is_staff", "is_superuser", "groups",
                       "user_permissions")

@admin.register(StudentProfile)
class StudentProfileAdmin(admin.ModelAdmin):
    list_display = ("user", "preferred_name", "institution", "department", "level")
    search_fields = ("user__email", "preferred_name", "institution", "department")

from .models import AcademicRecord
from .models import SupportTicket
@admin.register(AcademicRecord)
class AcademicRecordAdmin(admin.ModelAdmin):
    list_display = ("user", "kind", "record_id", "is_deleted", "modified_at")
    list_filter = ("kind", "is_deleted")
    search_fields = ("user__email", "record_id")
    readonly_fields = ("user", "kind", "record_id")
    def has_add_permission(self, request):
        return False


@admin.register(SupportTicket)
class SupportTicketAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "category", "created_at", "is_resolved")
    list_filter = ("category", "is_resolved", "created_at")
    search_fields = ("user__email", "message")
    readonly_fields = ("user", "category", "message", "created_at")


@admin.register(CampusBusinessSettings)
class CampusBusinessSettingsAdmin(admin.ModelAdmin):
    list_display = ("id", "trial_days", "offline_hours", "monthly_price_ngn", "quarterly_price_ngn", "default_referral_commission_ngn", "default_referral_quarterly_commission_ngn")
    def has_add_permission(self, request):
        return request.user.is_superuser and not CampusBusinessSettings.objects.exists()
    def has_delete_permission(self, request, obj=None):
        return False
    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser
    def save_model(self, request, obj, form, change):
        obj.pk = 1
        super().save_model(request, obj, form, change)


@admin.register(ReferralPartner)
class ReferralPartnerAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "university", "active", "commissions_enabled", "monthly_commission_override_ngn", "quarterly_commission_override_ngn", "commission_override_ngn")
    list_filter = ("active", "commissions_enabled", "university")
    search_fields = ("code", "name", "university")
    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser
    def has_add_permission(self, request):
        return request.user.is_superuser
    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser


@admin.register(PartnerReferralCode)
class PartnerReferralCodeAdmin(admin.ModelAdmin):
    list_display = ("code", "partner", "active", "created_at")
    list_filter = ("active", "partner")
    search_fields = ("code", "partner__name")
    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser
    def has_add_permission(self, request):
        return request.user.is_superuser
    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser


@admin.register(ReferralAttribution)
class ReferralAttributionAdmin(admin.ModelAdmin):
    list_display = ("user", "partner", "created_at")
    readonly_fields = ("user", "partner", "created_at")
    def has_add_permission(self, request): return False
    def has_delete_permission(self, request, obj=None): return False


@admin.register(SubscriptionPayment)
class SubscriptionPaymentAdmin(admin.ModelAdmin):
    list_display = ("external_reference", "user", "plan", "amount_ngn", "verified", "verified_at")
    list_filter = ("plan", "verified")
    search_fields = ("external_reference", "user__email")
    readonly_fields = ("verified", "verified_at", "created_at")
    actions = ["activate_verified_settlements"]
    @admin.action(description="Activate ONLY payments independently verified as settled")
    def activate_verified_settlements(self, request, queryset):
        if not request.user.is_superuser:
            self.message_user(request, "Only the owner can activate subscriptions.", level="error")
            return
        for payment in queryset:
            try:
                verify_recorded_payment(payment.pk)
            except Exception as error:
                self.message_user(request, f"{payment.external_reference}: {error}", level="error")
    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser
    def has_add_permission(self, request):
        return request.user.is_superuser
    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(ReferralReward)
class ReferralRewardAdmin(admin.ModelAdmin):
    list_display = ("user", "partner", "amount_ngn", "paid_out", "created_at")
    list_filter = ("paid_out", "partner")
    readonly_fields = ("user", "partner", "payment", "amount_ngn", "created_at")
    def has_add_permission(self, request): return False
    def has_delete_permission(self, request, obj=None): return False
    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser


from .models import StudentReferralCode, StudentReferralAttribution

@admin.register(StudentReferralCode)
class StudentReferralCodeAdmin(admin.ModelAdmin):
    list_display = ('code','user','created_at')
    search_fields = ('code','user__email')
    readonly_fields = ('user','code','created_at')
    def has_add_permission(self, request): return False
    def has_delete_permission(self, request, obj=None): return False

@admin.register(StudentReferralAttribution)
class StudentReferralAttributionAdmin(admin.ModelAdmin):
    list_display = ('user','referrer','created_at')
    search_fields = ('user__email','referrer__email')
    readonly_fields = ('user','referrer','created_at')
    def has_add_permission(self, request): return False
    def has_delete_permission(self, request, obj=None): return False
