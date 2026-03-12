from django.urls import path
from .views import PaymentInvoiceView, PaymentStatusView, ProcessPaymentView, PaymentWebhookView

urlpatterns = [
    path('checkout/', ProcessPaymentView.as_view(), name='payment-checkout'),
    path('webhook/', PaymentWebhookView.as_view(), name='payment-webhook'),
    path('<int:payment_id>/status/', PaymentStatusView.as_view(), name='payment-status'),
    path('<int:payment_id>/invoice/', PaymentInvoiceView.as_view(), name='payment-invoice'),
]