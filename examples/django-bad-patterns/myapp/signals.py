from django.db.models.signals import post_save
from django.dispatch import receiver
from django.core.mail import send_mail

from .models import UserProfile, OrderHistory


@receiver(post_save, sender=UserProfile)
def user_created_handler(sender, instance, created, **kwargs):
    """Anti-pattern: business logic in signals."""
    if created:
        # Create default orders
        OrderHistory.objects.create(
            user=instance,
            product=Product.objects.filter(category__name='welcome').first(),
            quantity=1,
            total_price=0,
        )
        # Send welcome email
        send_mail(
            'Welcome!',
            f'Hello {instance.name}',
            'noreply@example.com',
            [instance.email],
        )
        # Update analytics
        from analytics.models import Event
        Event.objects.create(type='user_signup', user=instance)
