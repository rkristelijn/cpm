# Angular Security Patterns

Checkable security patterns for Angular applications based on Angular Security Workshop and Angular.io security guide.

## XSS Prevention

### 1. DomSanitizer Required for Dynamic Values
Angular treats all values as untrusted by default. When binding dynamic content, use `DomSanitizer` with appropriate security contexts.

```typescript
// SAFE: Using DomSanitizer for specific contexts
this.sanitizer.bypassSecurityTrustHtml(htmlString);      // HTML context
this.sanitizer.bypassSecurityTrustStyle(styleString);    // CSS context
this.sanitizer.bypassSecurityTrustUrl(urlString);        // URL context
this.sanitizer.bypassSecurityTrustResourceUrl(urlString); // Resource URL
```

**Check**: Files using `innerHTML`/`outerHTML` without `DomSanitizer` calls.

### 2. Avoid bypassSecurityTrust* When Possible
Using `bypassSecurityTrust*` bypasses Angular's XSS protection. Only use when absolutely necessary and content is trusted.

**Check**: Presence of `bypassSecurityTrustHtml`, `bypassSecurityTrustScript`, etc.

### 3. Template Binding Over Direct DOM
Use Angular's template binding instead of direct `innerHTML`/`outerHTML` assignment.

```typescript
// AVOID
element.innerHTML = userInput;

// PREFER
<div [innerHTML]="sanitizedContent"></div>
```

**Check**: Direct `innerHTML`/`outerHTML` assignments in `.ts` files.

## CSRF Protection

### 4. HttpClient XSRF Token Interceptor
Angular's `HttpClient` supports XSRF-TOKEN cookies for CSRF protection. Configure with `HttpClientXsrfModule`.

```typescript
import { HttpClientModule, HttpClientXsrfModule } from '@angular/common/http';

@NgModule({
  imports: [HttpClientModule, HttpClientXsrfModule.withOptions({
    cookieName: 'XSRF-TOKEN',
    headerName: 'X-XSRF-TOKEN'
  })],
})
export class AppModule {}
```

**Check**: `HttpClientModule` without `HttpClientXsrfModule` configuration.

### 5. XSRF Token Extraction for Custom Requests
When making custom HTTP requests, extract and include the XSRF token.

```typescript
// SAFE: Extract and include XSRF token
import { XsrrfService } from './xsrff.service';

constructor(private http: HttpClient, private xsrff: XsrffService) {}

deleteItem(id: string) {
  const headers = { 'X-XSRF-TOKEN': this.xsrff.getToken() };
  return this.http.delete(`/api/items/${id}`, { headers });
}
```

**Check**: Custom HTTP requests without XSRF token handling.

## Route Protection

### 6. Auth Guards for Protected Routes
Use `CanActivate` guards to protect routes from unauthorized access.

```typescript
@Injectable({ providedIn: 'root' })
export class AuthGuard implements CanActivate {
  constructor(private auth: AuthService, private router: Router) {}

  canActivate(route: ActivatedRouteSnapshot): boolean {
    if (this.auth.isAuthenticated()) {
      return true;
    }
    this.router.navigate(['/login']);
    return false;
  }
}
```

**Check**: Routes without `canActivate` guards.

### 7. Functional Guards (Angular 15+)
Prefer functional guards over class-based guards for better tree-shaking.

```typescript
// PREFER
export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  return auth.isAuthenticated() || router.createUrlTree(['/login']);
};

// AVOID (class-based)
@Injectable({ providedIn: 'root' })
export class AuthGuard implements CanActivate { ... }
```

**Check**: Class-based guards when functional alternatives exist.

### 8. Lazy Loading with loadComponent
Use `loadComponent` for lazy loading standalone routes.

```typescript
// SAFE: Lazy loaded standalone component
{
  path: 'admin',
  loadComponent: () => import('./admin/admin.component').then(m => m.AdminComponent)
}

// AVOID: Eager loading
{ path: 'admin', component: AdminComponent }
```

**Check**: Eager component loading in routes.

## Content Security Policy

### 9. CSP Meta Tag or HTTP Header
Configure Content-Security-Policy to prevent XSS attacks.

```html
<!-- index.html -->
<meta http-equiv="Content-Security-Policy" 
      content="default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self'">
```

**Check**: Missing CSP configuration in `index.html` or server headers.

### 10. No Inline Scripts/Styles When Possible
Avoid inline `<script>` and `style` attributes. Use external files.

```html
<!-- AVOID -->
<script>console.log('inline');</script>
<div style="color: red" onclick="alert('xss')">Click</div>

<!-- PREFER -->
<script src="app.js"></script>
<div [class.red]="isRed" (click)="handleClick()">Click</div>
```

**Check**: Inline scripts or `javascript:` URLs in templates.

## HttpClient Security

### 11. Interceptors for Auth Headers
Use HTTP interceptors for consistent authentication header injection.

```typescript
@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    const token = this.auth.getToken();
    const authReq = req.clone({
      setHeaders: { Authorization: `Bearer ${token}` }
    });
    return next.handle(authReq);
  }
}
```

**Check**: Manual auth header setting without interceptors.

### 12. Type-Safe HttpClient Responses
Use typed interfaces instead of `<any>` for type safety.

```typescript
// SAFE: Typed response
interface UserResponse { id: number; name: string; email: string; }
this.http.get<UserResponse>('/api/user').subscribe(user => {
  console.log(user.name); // Type-safe
});

// AVOID: Any type
this.http.get<any>('/api/user').subscribe(user => { ... });
```

**Check**: `HttpClient` calls with `<any>` generic type.

## CORS and Server-Side Validation

### 13. Server-Side CORS Configuration
Configure CORS on the server, not the client.

```typescript
// AVOID: Client-side CORS workarounds
// CORS is a SERVER configuration, not client

// SAFE: Server config (Express example)
app.use(cors({
  origin: 'https://trusted-domain.com',
  credentials: true
}));
```

**Check**: Client-side code attempting CORS configuration.

### 14. Server-Side Input Validation
Never trust client-side validation. Validate on server.

```typescript
// AVOID: Client-only validation
submitForm() {
  if (this.form.valid) {  // Only client check
    this.http.post('/api/data', this.form.value).subscribe();
  }
}
```

**Check**: Forms without server-side validation patterns.

## Additional Security Patterns

### 15. Environment-Based API URLs
Use environment files for API URLs to prevent exposure.

```typescript
// environment.prod.ts
export const environment = {
  production: true,
  apiUrl: 'https://api.secure-domain.com'
};

// environment.ts
export const environment = {
  production: false,
  apiUrl: 'http://localhost:3000'
};
```

**Check**: Hardcoded API URLs in components.

### 16. No Secrets in Client-Side Code
Never include API keys, secrets, or credentials in client code.

```typescript
// AVOID: Secret in code
const API_KEY = 'sk-1234567890abcdef';

// SAFE: Environment variable (build-time)
const API_KEY = environment.apiKey; // Set during build
```

**Check**: Patterns matching API keys, tokens, or secrets in source.

### 17. Safe URL Handling
Use Angular's router for URL navigation instead of raw string concatenation.

```typescript
// SAFE: Router navigation
this.router.navigate(['/users', userId, 'profile']);

// AVOID: String concatenation
this.router.navigateByUrl('/users/' + userId + '/profile');
```

**Check**: `navigateByUrl` with string concatenation.

### 18. Sanitize External Content
When displaying content from external sources, always sanitize.

```typescript
// SAFE: Sanitize external HTML
import { DomSanitizer } from '@angular/platform-browser';

constructor(private sanitizer: DomSanitizer) {}

loadExternalContent(html: string) {
  // Sanitize before binding
  this.safeContent = this.sanitizer.bypassSecurityTrustHtml(html);
}
```

**Check**: External content bound without sanitization.

### 19. No Dangerous URL Protocols
Prevent `javascript:` and `data:` URL protocols in bindings.

```typescript
// AVOID: Dangerous protocol
<a [href]="userProvidedUrl">Link</a>

// SAFE: Validate URL protocol
isSafeUrl(url: string): boolean {
  const allowed = ['https:', 'mailto:'];
  const urlObj = new URL(url, window.location.origin);
  return allowed.includes(urlObj.protocol);
}
```

**Check**: User-provided URLs without protocol validation.

### 20. Secure Cookie Configuration
When using cookies, configure security options.

```typescript
// SAFE: Secure cookie settings
// Set on server:
// Set-Cookie: session=abc123; Secure; HttpOnly; SameSite=Strict
```

**Check**: Sensitive data in cookies without security flags.

## References

- [Angular Security Guide](https://angular.io/guide/security)
- [Angular Security Workshop](~/git/hub/work-epub/frontend/angular-security-workshop/not-pluralsight-angular-security-workshop.md)
- [Content Security Policy](https://developers.google.com/web/fundamentals/security/csp)
- [OWASP XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)