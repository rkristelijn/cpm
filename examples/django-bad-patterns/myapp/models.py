import pickle
from django.db import models
from django.utils.encoding import smart_text
from orders.models import Order
from payments.models import Payment
from notifications.models import Notification
from analytics.models import Event


class UserProfile(models.Model):
    name = models.CharField(max_length=100)
    email = models.EmailField()
    data = models.TextField()

    def load_preferences(self):
        return pickle.loads(self.data.encode())

    def get_orders(self):
        return self.order_set.all()

    def get_label(self):
        return smart_text(self.name)


# Padding to make it >300 lines for fat model detection
class Product(models.Model):
    title = models.CharField(max_length=200)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    description = models.TextField()
    category = models.ForeignKey('Category', on_delete=models.CASCADE)

class Category(models.Model):
    name = models.CharField(max_length=100)

class Review(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    rating = models.IntegerField()
    comment = models.TextField()

class Tag(models.Model):
    name = models.CharField(max_length=50)
    products = models.ManyToManyField(Product)

class Inventory(models.Model):
    product = models.OneToOneField(Product, on_delete=models.CASCADE)
    quantity = models.IntegerField(default=0)

class Supplier(models.Model):
    name = models.CharField(max_length=200)
    email = models.EmailField()
    phone = models.CharField(max_length=20)
    address = models.TextField()

class Warehouse(models.Model):
    name = models.CharField(max_length=100)
    location = models.CharField(max_length=200)

class Shipment(models.Model):
    warehouse = models.ForeignKey(Warehouse, on_delete=models.CASCADE)
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    quantity = models.IntegerField()
    shipped_at = models.DateTimeField(auto_now_add=True)

class Discount(models.Model):
    code = models.CharField(max_length=20)
    percentage = models.IntegerField()
    valid_from = models.DateTimeField()
    valid_until = models.DateTimeField()

class CartItem(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    quantity = models.IntegerField(default=1)
    session_key = models.CharField(max_length=40)

class Wishlist(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE)
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    added_at = models.DateTimeField(auto_now_add=True)

class Brand(models.Model):
    name = models.CharField(max_length=100)
    logo = models.ImageField(upload_to='brands/')
    website = models.URLField()

class ProductImage(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    image = models.ImageField(upload_to='products/')
    alt_text = models.CharField(max_length=200)
    is_primary = models.BooleanField(default=False)

class ProductVariant(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    sku = models.CharField(max_length=50)
    price_override = models.DecimalField(max_digits=10, decimal_places=2, null=True)
    stock = models.IntegerField(default=0)

class OrderHistory(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE)
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    quantity = models.IntegerField()
    total_price = models.DecimalField(max_digits=10, decimal_places=2)
    ordered_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=20, default='pending')

class ReturnRequest(models.Model):
    order = models.ForeignKey(OrderHistory, on_delete=models.CASCADE)
    reason = models.TextField()
    status = models.CharField(max_length=20, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)

class PaymentMethod(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE)
    method_type = models.CharField(max_length=20)
    last_four = models.CharField(max_length=4)
    is_default = models.BooleanField(default=False)

class Address(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE)
    street = models.CharField(max_length=200)
    city = models.CharField(max_length=100)
    postal_code = models.CharField(max_length=20)
    country = models.CharField(max_length=100)
    is_default = models.BooleanField(default=False)

class Coupon(models.Model):
    code = models.CharField(max_length=30, unique=True)
    discount_amount = models.DecimalField(max_digits=10, decimal_places=2)
    min_purchase = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    max_uses = models.IntegerField(default=1)
    used_count = models.IntegerField(default=0)
    expires_at = models.DateTimeField()

class Newsletter(models.Model):
    email = models.EmailField(unique=True)
    subscribed_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)

class FAQ(models.Model):
    question = models.TextField()
    answer = models.TextField()
    category = models.CharField(max_length=100)
    order = models.IntegerField(default=0)

class ContactMessage(models.Model):
    name = models.CharField(max_length=100)
    email = models.EmailField()
    subject = models.CharField(max_length=200)
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)

class SiteSettings(models.Model):
    site_name = models.CharField(max_length=100)
    tagline = models.CharField(max_length=200)
    maintenance_mode = models.BooleanField(default=False)
    analytics_id = models.CharField(max_length=50, blank=True)

class AuditLog(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.SET_NULL, null=True)
    action = models.CharField(max_length=50)
    model_name = models.CharField(max_length=100)
    object_id = models.IntegerField()
    changes = models.JSONField(default=dict)
    timestamp = models.DateTimeField(auto_now_add=True)

class Notification2(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

class Banner(models.Model):
    title = models.CharField(max_length=100)
    image = models.ImageField(upload_to='banners/')
    link = models.URLField(blank=True)
    is_active = models.BooleanField(default=True)
    start_date = models.DateTimeField()
    end_date = models.DateTimeField()

class SearchQuery(models.Model):
    query = models.CharField(max_length=200)
    results_count = models.IntegerField(default=0)
    searched_at = models.DateTimeField(auto_now_add=True)
    user = models.ForeignKey(UserProfile, on_delete=models.SET_NULL, null=True, blank=True)

class ShippingMethod(models.Model):
    name = models.CharField(max_length=100)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    estimated_days = models.IntegerField()
    is_active = models.BooleanField(default=True)

class TaxRate(models.Model):
    country = models.CharField(max_length=100)
    rate = models.DecimalField(max_digits=5, decimal_places=2)
    description = models.CharField(max_length=200)

class Currency(models.Model):
    code = models.CharField(max_length=3)
    name = models.CharField(max_length=50)
    symbol = models.CharField(max_length=5)
    exchange_rate = models.DecimalField(max_digits=10, decimal_places=6)

class ProductAttribute(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    value = models.CharField(max_length=200)

class ProductBundle(models.Model):
    name = models.CharField(max_length=200)
    products = models.ManyToManyField(Product)
    discount_percentage = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)

class Referral(models.Model):
    referrer = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='referrals_made')
    referred = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='referred_by')
    code = models.CharField(max_length=20, unique=True)
    reward_claimed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

class LoyaltyPoints(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE)
    points = models.IntegerField(default=0)
    earned_from = models.CharField(max_length=100)
    earned_at = models.DateTimeField(auto_now_add=True)

class StockAlert(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE)
    threshold = models.IntegerField(default=1)
    is_active = models.BooleanField(default=True)
    notified_at = models.DateTimeField(null=True, blank=True)

class PriceHistory(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    old_price = models.DecimalField(max_digits=10, decimal_places=2)
    new_price = models.DecimalField(max_digits=10, decimal_places=2)
    changed_at = models.DateTimeField(auto_now_add=True)
    changed_by = models.ForeignKey(UserProfile, on_delete=models.SET_NULL, null=True)

class GiftCard(models.Model):
    code = models.CharField(max_length=20, unique=True)
    balance = models.DecimalField(max_digits=10, decimal_places=2)
    original_amount = models.DecimalField(max_digits=10, decimal_places=2)
    purchased_by = models.ForeignKey(UserProfile, on_delete=models.SET_NULL, null=True)
    is_active = models.BooleanField(default=True)
    expires_at = models.DateTimeField()

class ImportJob(models.Model):
    filename = models.CharField(max_length=200)
    status = models.CharField(max_length=20, default='pending')
    rows_processed = models.IntegerField(default=0)
    errors = models.JSONField(default=list)
    started_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True)

class ExportJob(models.Model):
    export_type = models.CharField(max_length=50)
    status = models.CharField(max_length=20, default='pending')
    file_url = models.URLField(blank=True)
    requested_by = models.ForeignKey(UserProfile, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

class Webhook(models.Model):
    url = models.URLField()
    event_type = models.CharField(max_length=50)
    is_active = models.BooleanField(default=True)
    secret = models.CharField(max_length=100)
    last_triggered = models.DateTimeField(null=True)
    failure_count = models.IntegerField(default=0)

class APIKey(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE)
    key = models.CharField(max_length=64, unique=True)
    name = models.CharField(max_length=100)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_used = models.DateTimeField(null=True)
    rate_limit = models.IntegerField(default=1000)

class FeatureFlag(models.Model):
    name = models.CharField(max_length=100, unique=True)
    is_enabled = models.BooleanField(default=False)
    description = models.TextField(blank=True)
    rollout_percentage = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

class Metric(models.Model):
    name = models.CharField(max_length=100)
    value = models.FloatField()
    tags = models.JSONField(default=dict)
    recorded_at = models.DateTimeField(auto_now_add=True)

class ScheduledTask(models.Model):
    name = models.CharField(max_length=100)
    cron_expression = models.CharField(max_length=50)
    is_active = models.BooleanField(default=True)
    last_run = models.DateTimeField(null=True)
    next_run = models.DateTimeField(null=True)
    task_path = models.CharField(max_length=200)
