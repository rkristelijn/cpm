// Fixture: Design pattern anti-patterns for PATTERN-001 through PATTERN-010
// @see R-030 (Design Patterns vs Native Platform Features)

// PATTERN-001: Singleton getInstance() in module-based language
class DatabaseConnection {
  private static instance: DatabaseConnection;
  private constructor() {}
  static getInstance(): DatabaseConnection {
    if (!DatabaseConnection.instance) {
      DatabaseConnection.instance = new DatabaseConnection();
    }
    return DatabaseConnection.instance;
  }
}

// PATTERN-002: DI container library in framework with native DI
import { Container } from 'inversify';
import { injectable } from 'tsyringe';

// PATTERN-003: Interface + single implementation pair
interface IUserService {
  getUser(id: string): Promise<User>;
}
class UserServiceImpl implements IUserService {
  async getUser(id: string) { return {} as User; }
}

// PATTERN-004: Empty catch blocks
try { await fetch('/api'); } catch (e) {}
const data = fetch('/api').then(r => r.json()).catch(() => {});

// PATTERN-005: Manual Observer/EventBus
class EventBus {
  private listeners: any[] = [];
  subscribe(observer: Observer) { this.listeners.push(observer); }
}

// PATTERN-006: External service call without circuit breaker
const res = await fetch('https://api.external.com/users/1');
await axios.post('https://notifications.service.com/send', {});

// PATTERN-007: Repository wrapper around ORM
class UserRepository extends Repository<User> {
  findById(id: string) { return this.find({ where: { id } }); }
}

// PATTERN-008: Builder for simple class
class UserBuilder {
  setName(name: string) { return this; }
  setAge(age: number) { return this; }
}
new UserBuilder().setName('John').setAge(30);

// PATTERN-009: Abstract Factory with single implementation
interface NotificationFactory {
  create(type: string): Notification;
}
class NotificationFactoryImpl implements NotificationFactory {
  create(type: string) { return {} as Notification; }
}
abstract class BaseWidgetFactory {
  abstract createWidget(): Widget;
}

// PATTERN-010: Strategy with single implementation
interface ValidationStrategy {
  validate(data: unknown): boolean;
}
class EmailValidationStrategy implements ValidationStrategy {
  validate(data: unknown) { return true; }
}
interface CachePolicy {
  evict(key: string): void;
}
