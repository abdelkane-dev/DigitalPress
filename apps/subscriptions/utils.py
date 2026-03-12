from datetime import timedelta
from django.utils import timezone

def calculate_end_date(subscription_type):
    now = timezone.now().date()
    if subscription_type == 'daily':
        return now + timedelta(days=1)
    elif subscription_type == 'monthly':
        return now + timedelta(days=30)
    elif subscription_type == 'yearly':
        return now + timedelta(days=365)
    return now