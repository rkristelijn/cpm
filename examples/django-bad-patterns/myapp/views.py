import yaml
from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.db import connection

from .models import UserProfile, Product


@csrf_exempt
def create_user(request):
    """No validation, direct POST access, csrf exempt."""
    name = request.POST['name']
    email = request.POST['email']
    user = UserProfile.objects.create(name=name, email=email)
    return JsonResponse({'id': user.id})


def search_users(request):
    """SQL injection via string formatting."""
    query = request.GET['q']
    cursor = connection.cursor()
    cursor.execute(f"SELECT * FROM myapp_userprofile WHERE name LIKE '%{query}%'")
    results = cursor.fetchall()
    return JsonResponse({'results': results}, safe=False)


def product_list(request):
    """N+1 query problem."""
    products = Product.objects.all()
    data = []
    for p in products:
        data.append({
            'title': p.title,
            'category': p.category_set.first().name,
        })
    return JsonResponse({'products': data}, safe=False)


def import_config(request):
    """Unsafe YAML deserialization."""
    config_data = request.POST['config']
    config = yaml.load(config_data)
    return JsonResponse({'status': 'ok', 'keys': list(config.keys())})


def upload_file(request):
    """File upload without size limits."""
    uploaded = request.FILES['document']
    with open(f'/tmp/{uploaded.name}', 'wb') as f:
        for chunk in uploaded.chunks():
            f.write(chunk)
    return JsonResponse({'filename': uploaded.name})


def get_raw_data(request):
    """Another raw SQL injection pattern."""
    user_id = request.GET['user_id']
    data = UserProfile.objects.raw(f"SELECT * FROM myapp_userprofile WHERE id = {user_id}")
    return JsonResponse({'data': list(data.values())}, safe=False)


# Padding lines to make >150 for fat views check
def dashboard(request):
    users = UserProfile.objects.all()
    products = Product.objects.all()
    return render(request, 'dashboard.html', {'users': users, 'products': products})


def user_detail(request, pk):
    user = UserProfile.objects.get(pk=pk)
    return JsonResponse({'name': user.name, 'email': user.email})


def product_detail(request, pk):
    product = Product.objects.get(pk=pk)
    return JsonResponse({'title': product.title})


def category_list(request):
    from .models import Category
    cats = Category.objects.all()
    return JsonResponse({'categories': [c.name for c in cats]}, safe=False)


def review_list(request, product_id):
    from .models import Review
    reviews = Review.objects.filter(product_id=product_id)
    return JsonResponse({'reviews': [{'rating': r.rating} for r in reviews]}, safe=False)


def tag_list(request):
    from .models import Tag
    tags = Tag.objects.all()
    return JsonResponse({'tags': [t.name for t in tags]}, safe=False)


def inventory_check(request, product_id):
    from .models import Inventory
    inv = Inventory.objects.get(product_id=product_id)
    return JsonResponse({'quantity': inv.quantity})


def supplier_list(request):
    from .models import Supplier
    suppliers = Supplier.objects.all()
    return JsonResponse({'suppliers': [s.name for s in suppliers]}, safe=False)


def warehouse_list(request):
    from .models import Warehouse
    warehouses = Warehouse.objects.all()
    return JsonResponse({'warehouses': [w.name for w in warehouses]}, safe=False)


def shipment_list(request):
    from .models import Shipment
    shipments = Shipment.objects.all()
    return JsonResponse({'count': shipments.count()})


def discount_list(request):
    from .models import Discount
    discounts = Discount.objects.all()
    return JsonResponse({'discounts': [d.code for d in discounts]}, safe=False)


def cart_view(request):
    from .models import CartItem
    items = CartItem.objects.filter(session_key=request.session.session_key)
    return JsonResponse({'items': items.count()})


def wishlist_view(request):
    from .models import Wishlist
    items = Wishlist.objects.filter(user_id=request.user.id)
    return JsonResponse({'items': items.count()})


def brand_list(request):
    from .models import Brand
    brands = Brand.objects.all()
    return JsonResponse({'brands': [b.name for b in brands]}, safe=False)


def newsletter_subscribe(request):
    from .models import Newsletter
    email = request.POST.get('email')
    Newsletter.objects.create(email=email)
    return JsonResponse({'status': 'subscribed'})


def faq_list(request):
    from .models import FAQ
    faqs = FAQ.objects.all().order_by('order')
    return JsonResponse({'faqs': [{'q': f.question, 'a': f.answer} for f in faqs]}, safe=False)


def contact(request):
    from .models import ContactMessage
    if request.method == 'POST':
        ContactMessage.objects.create(
            name=request.POST['name'],
            email=request.POST['email'],
            subject=request.POST['subject'],
            message=request.POST['message'],
        )
    return JsonResponse({'status': 'sent'})


def health_check(request):
    return JsonResponse({'status': 'ok'})
