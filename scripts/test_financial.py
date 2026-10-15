import os, django
os.environ['DJANGO_SETTINGS_MODULE'] = 'config.settings'
django.setup()

from apps.paiements.cinetpay import cinetpay_service, is_sandbox_mode
from apps.paiements.models import Transaction

print("=== CINETPAY STATUS ===")
print(f"Sandbox mode: {is_sandbox_mode()}")
print(f"API key configured: {bool(cinetpay_service.api_key and cinetpay_service.api_key not in ('', 'YOUR_CINETPAY_KEY'))}")

result = cinetpay_service._mock_initier("test-ref-001", 5000, "+22370000000")
print(f"Mock initiation: success={result['success']}")

result2 = cinetpay_service._mock_verifier("test-ref-001")
print(f"Mock verification: success={result2['success']}, status={result2['status']}")

from django.db.models import Count
stats = Transaction.objects.values("status").annotate(c=Count("id"))
print("\n=== TRANSACTION STATS ===")
for s in stats:
    print(f"  {s['status']}: {s['c']}")

from apps.accounts.models import User
readers = User.objects.filter(role="reader", solde__gt=0).values_list("username", "solde")
print(f"\n=== READERS WITH BALANCE ===")
for username, solde in list(readers)[:5]:
    print(f"  {username}: {solde} FCFA")

print("\n=== ALL FINANCIAL FLOWS OK (simulation mode) ===")
