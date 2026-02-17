@echo off
cls
color 30
echo ============================================================
echo =                                                          =
echo =     DDD + CQRS + Hexagonal + Onion + Event Sourcing     =
echo =           Enhanced Edition - PURE DOMAIN v2             =
echo =                                                          =
echo ============================================================
echo.

set /p projectName="Ingrese el nombre del proyecto: "
set projectDirectory=%cd%\%projectName%

if exist "%projectDirectory%" (
    echo El directorio "%projectDirectory%" ya existe. Saliendo del script.
    pause
    exit
)

echo.
echo === Seleccione el tipo de CQRS ===
echo.
echo 1. CQRS Light (mismo modelo para lectura/escritura)
echo    [+] Facil de implementar
echo    [+] Ideal para proyectos pequenos/medianos
echo.
echo 2. CQRS Real con EF (Read Model separado + Entity Framework)
echo    [+] Read Model denormalizado
echo    [+] Proyecciones desde eventos
echo.
echo 3. CQRS Real con Dapper (maximo rendimiento)
echo    [+] Queries con SQL raw via Dapper
echo    [+] Maximo rendimiento en lectura
echo.
set /p cqrsType="Ingrese su eleccion (1, 2 o 3): "

if "%cqrsType%"=="1" (
    set cqrsMode=Light
    set useDapper=false
    echo [OK] Modo seleccionado: CQRS Light
) else if "%cqrsType%"=="2" (
    set cqrsMode=RealEF
    set useDapper=false
    echo [OK] Modo seleccionado: CQRS Real con EF
) else if "%cqrsType%"=="3" (
    set cqrsMode=RealDapper
    set useDapper=true
    echo [OK] Modo seleccionado: CQRS Real con Dapper
) else (
    echo [WARN] Opcion no valida. Se utilizara CQRS Light
    set cqrsMode=Light
    set useDapper=false
)

echo.
echo === Creando estructura de directorios ===
mkdir "%projectDirectory%"
mkdir "%projectDirectory%\src"
mkdir "%projectDirectory%\tests"
mkdir "%projectDirectory%\docs"

cd "%projectDirectory%\src"
dotnet new sln --name %projectName%

echo.
echo === Creando proyectos Core ===
dotnet new classlib -o "%projectName%.Domain"
dotnet sln add "%projectName%.Domain"
if exist "%projectName%.Domain\Class1.cs" del /f /q "%projectName%.Domain\Class1.cs"

dotnet new classlib -o "%projectName%.Application"
dotnet sln add "%projectName%.Application"
if exist "%projectName%.Application\Class1.cs" del /f /q "%projectName%.Application\Class1.cs"

echo.
echo === Creando proyectos Infrastructure ===
dotnet new classlib -o "%projectName%.Infrastructure"
dotnet sln add "%projectName%.Infrastructure"
if exist "%projectName%.Infrastructure\Class1.cs" del /f /q "%projectName%.Infrastructure\Class1.cs"

echo.
echo === Creando capa de Presentacion ===
echo 1. Web API (Recomendado)
echo 2. MVC
echo 3. Blazor Server
set /p uiType="Seleccione (1-3): "

if "%uiType%"=="1" (
    dotnet new webapi -o "%projectName%.API"
    dotnet sln add "%projectName%.API"
    set uiProject=API
    if exist "%projectName%.API\Controllers\WeatherForecastController.cs" del /f /q "%projectName%.API\Controllers\WeatherForecastController.cs"
    if exist "%projectName%.API\WeatherForecast.cs" del /f /q "%projectName%.API\WeatherForecast.cs"
    if exist "%projectName%.API\Controllers" rd /q "%projectName%.API\Controllers" 2>nul
) else if "%uiType%"=="2" (
    dotnet new mvc -o "%projectName%.Web"
    dotnet sln add "%projectName%.Web"
    set uiProject=Web
) else if "%uiType%"=="3" (
    dotnet new blazorserver -o "%projectName%.Web"
    dotnet sln add "%projectName%.Web"
    set uiProject=Web
) else (
    dotnet new webapi -o "%projectName%.API"
    dotnet sln add "%projectName%.API"
    set uiProject=API
    if exist "%projectName%.API\Controllers\WeatherForecastController.cs" del /f /q "%projectName%.API\Controllers\WeatherForecastController.cs"
    if exist "%projectName%.API\WeatherForecast.cs" del /f /q "%projectName%.API\WeatherForecast.cs"
    if exist "%projectName%.API\Controllers" rd /q "%projectName%.API\Controllers" 2>nul
)

echo.
echo === Instalando paquetes NuGet ===

REM Application packages
cd "%projectName%.Application"
dotnet add package MediatR
dotnet add package FluentValidation
dotnet add package AutoMapper.Extensions.Microsoft.DependencyInjection
dotnet restore

REM Infrastructure packages
cd "..\%projectName%.Infrastructure"
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
dotnet add package Microsoft.EntityFrameworkCore.Design
dotnet add package Newtonsoft.Json

if "%useDapper%"=="true" (
    echo [INFO] Instalando Dapper para queries optimizadas...
    dotnet add package Dapper
    dotnet add package Microsoft.Data.SqlClient
)

dotnet restore

REM UI packages
cd "..\%projectName%.%uiProject%"
dotnet add package MediatR
dotnet add package Swashbuckle.AspNetCore
dotnet restore

cd ..

echo.
echo ============================================================
echo === CREANDO DOMAIN LAYER (100%% PURO) ===
echo ============================================================

mkdir "%projectName%.Domain\Common"
mkdir "%projectName%.Domain\Entities"
mkdir "%projectName%.Domain\ValueObjects"
mkdir "%projectName%.Domain\Events"
mkdir "%projectName%.Domain\Specifications"
mkdir "%projectName%.Domain\Exceptions"

REM ========== IDENTITIES (VALUE OBJECTS) ==========

(
echo namespace %projectName%.Domain.Common;
echo.
echo /// ^<summary^>
echo /// Value Object base para identidades
echo /// ^</summary^>
echo public abstract class Identity^<T^> : ValueObject where T : notnull
echo {
echo     public T Value { get; }
echo.
echo     protected Identity^(T value^)
echo     {
echo         if ^(value == null ^|^| value.Equals^(default^(T^)^)^)
echo             throw new ArgumentException^("Identity cannot be empty"^);
echo.
echo         Value = value;
echo     }
echo.
echo     protected override IEnumerable^<object^> GetEqualityComponents^(^)
echo     {
echo         yield return Value;
echo     }
echo.
echo     public override string ToString^(^) =^> Value.ToString^(^)!;
echo }
) > "%projectName%.Domain\Common\Identity.cs"

(
echo namespace %projectName%.Domain.Common;
echo.
echo public sealed class ProductId : Identity^<int^>
echo {
echo     private ProductId^(int value^) : base^(value^) { }
echo     public static ProductId Create^(^) =^> new^(0^);
echo     public static ProductId From^(int value^) =^> new^(value^);
echo }
echo.
echo public sealed class CustomerId : Identity^<int^>
echo {
echo     private CustomerId^(int value^) : base^(value^) { }
echo     public static CustomerId Create^(^) =^> new^(0^);
echo     public static CustomerId From^(int value^) =^> new^(value^);
echo }
echo.
echo public sealed class OrderId : Identity^<int^>
echo {
echo     private OrderId^(int value^) : base^(value^) { }
echo     public static OrderId Create^(^) =^> new^(0^);
echo     public static OrderId From^(int value^) =^> new^(value^);
echo }
echo.
echo public sealed class OrderItemId : Identity^<int^>
echo {
echo     private OrderItemId^(int value^) : base^(value^) { }
echo     public static OrderItemId Create^(^) =^> new^(0^);
echo     public static OrderItemId From^(int value^) =^> new^(value^);
echo }
) > "%projectName%.Domain\Common\DomainIds.cs"

REM ========== BASE ENTITIES ==========

(
echo namespace %projectName%.Domain.Common;
echo.
echo public abstract class Entity^<TId^> where TId : class
echo {
echo     private readonly List^<IDomainEvent^> _domainEvents = new^(^);
echo.
echo     public TId Id { get; protected set; } = null!;
echo     public DateTime CreatedAt { get; protected set; } = DateTime.UtcNow;
echo     public DateTime? UpdatedAt { get; protected set; }
echo.
echo     public IReadOnlyCollection^<IDomainEvent^> DomainEvents =^> _domainEvents.AsReadOnly^(^);
echo.
echo     protected void AddDomainEvent^(IDomainEvent eventItem^)
echo     {
echo         _domainEvents.Add^(eventItem^);
echo     }
echo.
echo     public void ClearDomainEvents^(^) =^> _domainEvents.Clear^(^);
echo }
) > "%projectName%.Domain\Common\Entity.cs"

(
echo namespace %projectName%.Domain.Common;
echo.
echo public abstract class AggregateRoot^<TId^> : Entity^<TId^> where TId : class
echo {
echo     public int Version { get; protected set; }
echo     protected void IncrementVersion^(^) =^> Version++;
echo }
) > "%projectName%.Domain\Common\AggregateRoot.cs"

(
echo namespace %projectName%.Domain.Common;
echo.
echo public abstract class ValueObject
echo {
echo     protected abstract IEnumerable^<object^> GetEqualityComponents^(^);
echo.
echo     public override bool Equals^(object? obj^)
echo     {
echo         if ^(obj == null ^|^| obj.GetType^(^) != GetType^(^)^) return false;
echo         var other = ^(ValueObject^)obj;
echo         return GetEqualityComponents^(^).SequenceEqual^(other.GetEqualityComponents^(^)^);
echo     }
echo.
echo     public override int GetHashCode^(^) =^>
echo         GetEqualityComponents^(^).Select^(x =^> x?.GetHashCode^(^) ?? 0^).Aggregate^(^(x, y^) =^> x ^^ y^);
echo }
) > "%projectName%.Domain\Common\ValueObject.cs"

(
echo namespace %projectName%.Domain.Common;
echo.
echo public interface IDomainEvent
echo {
echo     DateTime OccurredOn { get; }
echo     Guid EventId { get; }
echo }
echo.
echo public abstract class DomainEvent : IDomainEvent
echo {
echo     public DateTime OccurredOn { get; } = DateTime.UtcNow;
echo     public Guid EventId { get; } = Guid.NewGuid^(^);
echo }
) > "%projectName%.Domain\Common\IDomainEvent.cs"

(
echo namespace %projectName%.Domain.Exceptions;
echo.
echo public class DomainException : Exception
echo {
echo     public DomainException^(^) { }
echo     public DomainException^(string message^) : base^(message^) { }
echo     public DomainException^(string message, Exception innerException^) : base^(message, innerException^) { }
echo }
) > "%projectName%.Domain\Exceptions\DomainException.cs"

REM ========== VALUE OBJECTS ==========

(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Exceptions;
echo using System.Text.RegularExpressions;
echo.
echo namespace %projectName%.Domain.ValueObjects;
echo.
echo public sealed class Email : ValueObject
echo {
echo     public string Address { get; }
echo.
echo     public Email^(string address^)
echo     {
echo         if ^(string.IsNullOrWhiteSpace^(address^)^)
echo             throw new DomainException^("Email cannot be empty"^);
echo.
echo         if ^(!IsValidEmail^(address^)^)
echo             throw new DomainException^($"Invalid email: {address}"^);
echo.
echo         Address = address.ToLowerInvariant^(^);
echo     }
echo.
echo     private static bool IsValidEmail^(string email^) =^>
echo         Regex.IsMatch^(email, @"^^[^^@\s]+@[^^@\s]+\.[^^@\s]+$"^);
echo.
echo     protected override IEnumerable^<object^> GetEqualityComponents^(^)
echo     {
echo         yield return Address;
echo     }
echo.
echo     public static implicit operator string^(Email email^) =^> email.Address;
echo }
) > "%projectName%.Domain\ValueObjects\Email.cs"

(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Exceptions;
echo.
echo namespace %projectName%.Domain.ValueObjects;
echo.
echo public sealed class Money : ValueObject
echo {
echo     public decimal Amount { get; }
echo     public string Currency { get; }
echo.
echo     public Money^(decimal amount, string currency = "USD"^)
echo     {
echo         if ^(amount ^< 0^) throw new DomainException^("Amount cannot be negative"^);
echo         if ^(string.IsNullOrWhiteSpace^(currency^)^) throw new DomainException^("Currency required"^);
echo.
echo         Amount = amount;
echo         Currency = currency.ToUpperInvariant^(^);
echo     }
echo.
echo     public Money Add^(Money other^)
echo     {
echo         if ^(Currency != other.Currency^)
echo             throw new DomainException^("Cannot add different currencies"^);
echo         return new Money^(Amount + other.Amount, Currency^);
echo     }
echo.
echo     public Money Multiply^(decimal factor^) =^> new Money^(Amount * factor, Currency^);
echo.
echo     protected override IEnumerable^<object^> GetEqualityComponents^(^)
echo     {
echo         yield return Amount;
echo         yield return Currency;
echo     }
echo }
) > "%projectName%.Domain\ValueObjects\Money.cs"

REM ========== DOMAIN ENTITIES ==========

(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Events;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Domain.Entities;
echo.
echo public sealed class Product : AggregateRoot^<ProductId^>
echo {
echo     public string Name { get; private set; } = string.Empty;
echo     public Money Price { get; private set; } = null!;
echo     public string Description { get; private set; } = string.Empty;
echo     public bool IsActive { get; private set; }
echo     public int Stock { get; private set; }
echo.
echo     public Product^(ProductId id, string name, Money price, string description, int initialStock = 0^)
echo     {
echo         if ^(string.IsNullOrWhiteSpace^(name^)^) throw new DomainException^("Name required"^);
echo         if ^(initialStock ^< 0^) throw new DomainException^("Stock cannot be negative"^);
echo.
echo         Id = id;
echo         Name = name;
echo         Price = price;
echo         Description = description;
echo         Stock = initialStock;
echo         IsActive = true;
echo.
echo         AddDomainEvent^(new ProductCreatedEvent^(this^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void UpdatePrice^(Money newPrice^)
echo     {
echo         var oldPrice = Price;
echo         Price = newPrice;
echo         UpdatedAt = DateTime.UtcNow;
echo         AddDomainEvent^(new ProductPriceChangedEvent^(this, oldPrice, newPrice^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void AddStock^(int quantity^)
echo     {
echo         if ^(quantity ^<= 0^) throw new DomainException^("Quantity must be ^> 0"^);
echo         Stock += quantity;
echo         UpdatedAt = DateTime.UtcNow;
echo         AddDomainEvent^(new StockAddedEvent^(this, quantity^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void RemoveStock^(int quantity^)
echo     {
echo         if ^(quantity ^<= 0^) throw new DomainException^("Quantity must be ^> 0"^);
echo         if ^(Stock ^< quantity^) throw new DomainException^($"Insufficient stock: {Stock} ^< {quantity}"^);
echo.
echo         Stock -= quantity;
echo         UpdatedAt = DateTime.UtcNow;
echo         AddDomainEvent^(new StockRemovedEvent^(this, quantity^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void Deactivate^(^)
echo     {
echo         IsActive = false;
echo         UpdatedAt = DateTime.UtcNow;
echo         AddDomainEvent^(new ProductDeactivatedEvent^(this^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void Activate^(^)
echo     {
echo         IsActive = true;
echo         UpdatedAt = DateTime.UtcNow;
echo         IncrementVersion^(^);
echo     }
echo }
) > "%projectName%.Domain\Entities\Product.cs"

(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Events;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Domain.Entities;
echo.
echo public sealed class Customer : AggregateRoot^<CustomerId^>
echo {
echo     public string FirstName { get; private set; } = string.Empty;
echo     public string LastName { get; private set; } = string.Empty;
echo     public Email Email { get; private set; } = null!;
echo     public bool IsActive { get; private set; }
echo.
echo     public Customer^(CustomerId id, string firstName, string lastName, Email email^)
echo     {
echo         if ^(string.IsNullOrWhiteSpace^(firstName^)^) throw new DomainException^("FirstName required"^);
echo         if ^(string.IsNullOrWhiteSpace^(lastName^)^) throw new DomainException^("LastName required"^);
echo.
echo         Id = id;
echo         FirstName = firstName;
echo         LastName = lastName;
echo         Email = email;
echo         IsActive = true;
echo.
echo         AddDomainEvent^(new CustomerCreatedEvent^(this^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public string GetFullName^(^) =^> $"{FirstName} {LastName}";
echo.
echo     public void UpdateEmail^(Email newEmail^)
echo     {
echo         Email = newEmail;
echo         UpdatedAt = DateTime.UtcNow;
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void Deactivate^(^)
echo     {
echo         IsActive = false;
echo         UpdatedAt = DateTime.UtcNow;
echo         IncrementVersion^(^);
echo     }
echo }
) > "%projectName%.Domain\Entities\Customer.cs"

(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Events;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Domain.Entities;
echo.
echo public sealed class Order : AggregateRoot^<OrderId^>
echo {
echo     public CustomerId CustomerId { get; private set; } = null!;
echo     public DateTime OrderDate { get; private set; }
echo     public OrderStatus Status { get; private set; }
echo.
echo     private readonly List^<OrderItem^> _items = new^(^);
echo     public IReadOnlyCollection^<OrderItem^> Items =^> _items.AsReadOnly^(^);
echo.
echo     public Order^(OrderId id, CustomerId customerId^)
echo     {
echo         Id = id;
echo         CustomerId = customerId;
echo         OrderDate = DateTime.UtcNow;
echo         Status = OrderStatus.Pending;
echo.
echo         AddDomainEvent^(new OrderCreatedEvent^(this^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void AddItem^(ProductId productId, Money unitPrice, int quantity^)
echo     {
echo         if ^(Status != OrderStatus.Pending^)
echo             throw new DomainException^("Cannot add items to non-pending order"^);
echo.
echo         var existing = _items.FirstOrDefault^(i =^> i.ProductId.Equals^(productId^)^);
echo         if ^(existing != null^)
echo         {
echo             existing.UpdateQuantity^(existing.Quantity + quantity^);
echo         }
echo         else
echo         {
echo             _items.Add^(new OrderItem^(OrderItemId.Create^(^), productId, unitPrice, quantity^)^);
echo         }
echo.
echo         UpdatedAt = DateTime.UtcNow;
echo         IncrementVersion^(^);
echo     }
echo.
echo     public Money GetTotal^(^)
echo     {
echo         if ^(!_items.Any^(^)^) return new Money^(0^);
echo         return _items.Select^(i =^> i.GetSubtotal^(^)^).Aggregate^(^(a, b^) =^> a.Add^(b^)^);
echo     }
echo.
echo     public void Confirm^(^)
echo     {
echo         if ^(Status != OrderStatus.Pending^) throw new DomainException^("Only pending orders can be confirmed"^);
echo         if ^(!_items.Any^(^)^) throw new DomainException^("Cannot confirm empty order"^);
echo.
echo         Status = OrderStatus.Confirmed;
echo         UpdatedAt = DateTime.UtcNow;
echo         AddDomainEvent^(new OrderConfirmedEvent^(this^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void Cancel^(^)
echo     {
echo         if ^(Status == OrderStatus.Shipped ^|^| Status == OrderStatus.Delivered^)
echo             throw new DomainException^("Cannot cancel shipped/delivered orders"^);
echo.
echo         Status = OrderStatus.Cancelled;
echo         UpdatedAt = DateTime.UtcNow;
echo         AddDomainEvent^(new OrderCancelledEvent^(this^)^);
echo         IncrementVersion^(^);
echo     }
echo }
echo.
echo public enum OrderStatus { Pending, Confirmed, Shipped, Delivered, Cancelled }
) > "%projectName%.Domain\Entities\Order.cs"

(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Domain.Entities;
echo.
echo public sealed class OrderItem : Entity^<OrderItemId^>
echo {
echo     public ProductId ProductId { get; private set; } = null!;
echo     public int Quantity { get; private set; }
echo     public Money UnitPrice { get; private set; } = null!;
echo.
echo     public OrderItem^(OrderItemId id, ProductId productId, Money unitPrice, int quantity^)
echo     {
echo         if ^(quantity ^<= 0^) throw new DomainException^("Quantity must be ^> 0"^);
echo.
echo         Id = id;
echo         ProductId = productId;
echo         Quantity = quantity;
echo         UnitPrice = unitPrice;
echo     }
echo.
echo     public void UpdateQuantity^(int newQuantity^)
echo     {
echo         if ^(newQuantity ^<= 0^) throw new DomainException^("Quantity must be ^> 0"^);
echo         Quantity = newQuantity;
echo         UpdatedAt = DateTime.UtcNow;
echo     }
echo.
echo     public Money GetSubtotal^(^) =^> UnitPrice.Multiply^(Quantity^);
echo }
) > "%projectName%.Domain\Entities\OrderItem.cs"

REM ========== DOMAIN EVENTS ==========

(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Domain.Events;
echo.
echo public sealed class ProductCreatedEvent : DomainEvent
echo {
echo     public Product Product { get; }
echo     public ProductCreatedEvent^(Product product^) =^> Product = product;
echo }
echo.
echo public sealed class ProductPriceChangedEvent : DomainEvent
echo {
echo     public Product Product { get; }
echo     public Money OldPrice { get; }
echo     public Money NewPrice { get; }
echo.
echo     public ProductPriceChangedEvent^(Product product, Money oldPrice, Money newPrice^)
echo     {
echo         Product = product;
echo         OldPrice = oldPrice;
echo         NewPrice = newPrice;
echo     }
echo }
echo.
echo public sealed class StockAddedEvent : DomainEvent
echo {
echo     public Product Product { get; }
echo     public int Quantity { get; }
echo.
echo     public StockAddedEvent^(Product product, int quantity^)
echo     {
echo         Product = product;
echo         Quantity = quantity;
echo     }
echo }
echo.
echo public sealed class StockRemovedEvent : DomainEvent
echo {
echo     public Product Product { get; }
echo     public int Quantity { get; }
echo.
echo     public StockRemovedEvent^(Product product, int quantity^)
echo     {
echo         Product = product;
echo         Quantity = quantity;
echo     }
echo }
echo.
echo public sealed class ProductDeactivatedEvent : DomainEvent
echo {
echo     public Product Product { get; }
echo     public ProductDeactivatedEvent^(Product product^) =^> Product = product;
echo }
echo.
echo public sealed class CustomerCreatedEvent : DomainEvent
echo {
echo     public Customer Customer { get; }
echo     public CustomerCreatedEvent^(Customer customer^) =^> Customer = customer;
echo }
echo.
echo public sealed class OrderCreatedEvent : DomainEvent
echo {
echo     public Order Order { get; }
echo     public OrderCreatedEvent^(Order order^) =^> Order = order;
echo }
echo.
echo public sealed class OrderConfirmedEvent : DomainEvent
echo {
echo     public Order Order { get; }
echo     public OrderConfirmedEvent^(Order order^) =^> Order = order;
echo }
echo.
echo public sealed class OrderCancelledEvent : DomainEvent
echo {
echo     public Order Order { get; }
echo     public OrderCancelledEvent^(Order order^) =^> Order = order;
echo }
) > "%projectName%.Domain\Events\DomainEvents.cs"

REM ========== SPECIFICATIONS ==========

(
echo using System.Linq.Expressions;
echo.
echo namespace %projectName%.Domain.Specifications;
echo.
echo public interface ISpecification^<T^>
echo {
echo     Expression^<Func^<T, bool^>^> Criteria { get; }
echo     bool IsSatisfiedBy^(T entity^);
echo }
echo.
echo public abstract class Specification^<T^> : ISpecification^<T^>
echo {
echo     public Expression^<Func^<T, bool^>^> Criteria { get; }
echo.
echo     protected Specification^(Expression^<Func^<T, bool^>^> criteria^) =^> Criteria = criteria;
echo.
echo     public bool IsSatisfiedBy^(T entity^) =^> Criteria.Compile^(^)^(entity^);
echo }
) > "%projectName%.Domain\Specifications\Specification.cs"

(
echo using %projectName%.Domain.Entities;
echo.
echo namespace %projectName%.Domain.Specifications;
echo.
echo public class ActiveProductsSpecification : Specification^<Product^>
echo {
echo     public ActiveProductsSpecification^(^) : base^(p =^> p.IsActive^) { }
echo }
echo.
echo public class ProductsInStockSpecification : Specification^<Product^>
echo {
echo     public ProductsInStockSpecification^(^) : base^(p =^> p.Stock ^> 0^) { }
echo }
echo.
echo public class ProductsByPriceRangeSpecification : Specification^<Product^>
echo {
echo     public ProductsByPriceRangeSpecification^(decimal minPrice, decimal maxPrice^)
echo         : base^(p =^> p.Price.Amount ^>= minPrice ^&^& p.Price.Amount ^<= maxPrice^) { }
echo }
) > "%projectName%.Domain\Specifications\ProductSpecifications.cs"

echo.
echo ============================================================
echo === CREANDO APPLICATION LAYER ===
echo ============================================================

mkdir "%projectName%.Application\Common\Interfaces"
mkdir "%projectName%.Application\Common\Behaviors"
mkdir "%projectName%.Application\Common\Mappings"
mkdir "%projectName%.Application\Commands\Products"
mkdir "%projectName%.Application\Queries\Products"
mkdir "%projectName%.Application\DTOs"
mkdir "%projectName%.Application\EventHandlers"

if NOT "%cqrsMode%"=="Light" (
    mkdir "%projectName%.Application\ReadModels"
    mkdir "%projectName%.Application\Projections"
)

REM ========== INTERFACES ==========

if "%cqrsMode%"=="Light" (
    (
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.Specifications;
echo.
echo namespace %projectName%.Application.Common.Interfaces;
echo.
echo public interface IRepository^<T, TId^> where T : AggregateRoot^<TId^> where TId : class
echo {
echo     Task^<T?^> GetByIdAsync^(TId id, CancellationToken ct = default^);
echo     Task^<IEnumerable^<T^>^> GetAllAsync^(CancellationToken ct = default^);
echo     Task^<IEnumerable^<T^>^> FindAsync^(ISpecification^<T^> spec, CancellationToken ct = default^);
echo     Task^<T^> AddAsync^(T entity, CancellationToken ct = default^);
echo     Task UpdateAsync^(T entity, CancellationToken ct = default^);
echo     Task DeleteAsync^(T entity, CancellationToken ct = default^);
echo }
echo.
echo public interface IProductRepository : IRepository^<Product, ProductId^> { }
echo public interface ICustomerRepository : IRepository^<Customer, CustomerId^> { }
echo public interface IOrderRepository : IRepository^<Order, OrderId^>
echo {
echo     Task^<IEnumerable^<Order^>^> GetOrdersByCustomerAsync^(CustomerId customerId, CancellationToken ct = default^);
echo }
    ) > "%projectName%.Application\Common\Interfaces\IRepository.cs"
) else (
    REM Write Repository
    (
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo.
echo namespace %projectName%.Application.Common.Interfaces;
echo.
echo public interface IWriteRepository^<T, TId^> where T : AggregateRoot^<TId^> where TId : class
echo {
echo     Task^<T?^> GetByIdAsync^(TId id, CancellationToken ct = default^);
echo     Task^<T^> AddAsync^(T entity, CancellationToken ct = default^);
echo     Task UpdateAsync^(T entity, CancellationToken ct = default^);
echo     Task DeleteAsync^(T entity, CancellationToken ct = default^);
echo }
echo.
echo public interface IProductWriteRepository : IWriteRepository^<Product, ProductId^> { }
echo public interface ICustomerWriteRepository : IWriteRepository^<Customer, CustomerId^> { }
echo public interface IOrderWriteRepository : IWriteRepository^<Order, OrderId^> { }
    ) > "%projectName%.Application\Common\Interfaces\IWriteRepository.cs"
    
    if "%useDapper%"=="true" (
        (
echo namespace %projectName%.Application.Common.Interfaces;
echo.
echo public interface IQueryService
echo {
echo     Task^<T?^> QuerySingleAsync^<T^>^(string sql, object? parameters = null, CancellationToken ct = default^);
echo     Task^<IEnumerable^<T^>^> QueryAsync^<T^>^(string sql, object? parameters = null, CancellationToken ct = default^);
echo     Task^<int^> ExecuteAsync^(string sql, object? parameters = null, CancellationToken ct = default^);
echo }
        ) > "%projectName%.Application\Common\Interfaces\IQueryService.cs"
    )
    if NOT "%useDapper%"=="true" (
        (
echo using %projectName%.Application.ReadModels;
echo using System.Linq.Expressions;
echo.
echo namespace %projectName%.Application.Common.Interfaces;
echo.
echo public interface IReadRepository^<TReadModel^> where TReadModel : class
echo {
echo     Task^<TReadModel?^> GetByIdAsync^(int id, CancellationToken ct = default^);
echo     Task^<IEnumerable^<TReadModel^>^> GetAllAsync^(CancellationToken ct = default^);
echo     Task^<IEnumerable^<TReadModel^>^> FindAsync^(Expression^<Func^<TReadModel, bool^>^> predicate, CancellationToken ct = default^);
echo }
echo.
echo public interface IProductReadRepository : IReadRepository^<ProductReadModel^> { }
echo public interface ICustomerReadRepository : IReadRepository^<CustomerReadModel^> { }
echo public interface IOrderReadRepository : IReadRepository^<OrderReadModel^> { }
        ) > "%projectName%.Application\Common\Interfaces\IReadRepository.cs"
    )
    
    (
echo namespace %projectName%.Application.Common.Interfaces;
echo.
echo public interface IProjectionWriter^<TReadModel^> where TReadModel : class
echo {
echo     Task InsertAsync^(TReadModel model, CancellationToken ct = default^);
echo     Task UpdateAsync^(TReadModel model, CancellationToken ct = default^);
echo     Task DeleteAsync^(int id, CancellationToken ct = default^);
echo     Task^<TReadModel?^> GetByIdAsync^(int id, CancellationToken ct = default^);
echo }
    ) > "%projectName%.Application\Common\Interfaces\IProjectionWriter.cs"
)

(
echo namespace %projectName%.Application.Common.Interfaces;
echo.
echo public interface IUnitOfWork
echo {
echo     Task^<int^> SaveChangesAsync^(CancellationToken ct = default^);
echo     Task BeginTransactionAsync^(CancellationToken ct = default^);
echo     Task CommitTransactionAsync^(CancellationToken ct = default^);
echo     Task RollbackTransactionAsync^(CancellationToken ct = default^);
echo }
) > "%projectName%.Application\Common\Interfaces\IUnitOfWork.cs"

(
echo namespace %projectName%.Application.Common.Interfaces;
echo.
echo public class StoredEvent
echo {
echo     public int Id { get; set; }
echo     public Guid EventId { get; set; }
echo     public string AggregateType { get; set; } = string.Empty;
echo     public int AggregateId { get; set; }
echo     public string EventType { get; set; } = string.Empty;
echo     public string EventData { get; set; } = string.Empty;
echo     public DateTime OccurredOn { get; set; }
echo     public int Version { get; set; }
echo }
) > "%projectName%.Application\Common\Interfaces\StoredEvent.cs"

(
echo using %projectName%.Domain.Common;
echo.
echo namespace %projectName%.Application.Common.Interfaces;
echo.
echo public interface IEventStore
echo {
echo     Task SaveEventAsync^(IDomainEvent domainEvent, string aggregateType, int aggregateId, CancellationToken ct = default^);
echo     Task^<IEnumerable^<StoredEvent^>^> GetEventsAsync^(string aggregateType, int aggregateId, CancellationToken ct = default^);
echo     Task^<IEnumerable^<StoredEvent^>^> GetAllEventsAsync^(CancellationToken ct = default^);
echo }
) > "%projectName%.Application\Common\Interfaces\IEventStore.cs"

(
echo using %projectName%.Domain.Common;
echo.
echo namespace %projectName%.Application.Common.Interfaces;
echo.
echo public interface IDomainEventDispatcher
echo {
echo     Task DispatchAsync^(IDomainEvent domainEvent, CancellationToken ct = default^);
echo     Task DispatchAsync^(IEnumerable^<IDomainEvent^> domainEvents, CancellationToken ct = default^);
echo }
) > "%projectName%.Application\Common\Interfaces\IDomainEventDispatcher.cs"

REM ========== READ MODELS ==========

if NOT "%cqrsMode%"=="Light" (
    (
echo namespace %projectName%.Application.ReadModels;
echo.
echo public class ProductReadModel
echo {
echo     public int Id { get; set; }
echo     public string Name { get; set; } = string.Empty;
echo     public decimal Price { get; set; }
echo     public string Currency { get; set; } = "USD";
echo     public string Description { get; set; } = string.Empty;
echo     public bool IsActive { get; set; }
echo     public int Stock { get; set; }
echo     public DateTime CreatedAt { get; set; }
echo     public DateTime? UpdatedAt { get; set; }
echo }
echo.
echo public class CustomerReadModel
echo {
echo     public int Id { get; set; }
echo     public string FirstName { get; set; } = string.Empty;
echo     public string LastName { get; set; } = string.Empty;
echo     public string FullName { get; set; } = string.Empty;
echo     public string Email { get; set; } = string.Empty;
echo     public bool IsActive { get; set; }
echo     public DateTime CreatedAt { get; set; }
echo }
echo.
echo public class OrderReadModel
echo {
echo     public int Id { get; set; }
echo     public int CustomerId { get; set; }
echo     public string CustomerName { get; set; } = string.Empty;
echo     public DateTime OrderDate { get; set; }
echo     public string Status { get; set; } = string.Empty;
echo     public decimal Total { get; set; }
echo     public string Currency { get; set; } = "USD";
echo     public int ItemCount { get; set; }
echo }
    ) > "%projectName%.Application\ReadModels\ReadModels.cs"
)

REM ========== COMMANDS EXTENDIDOS ==========

REM CreateProductCommand
(
echo using MediatR;
echo using %projectName%.Domain.Common;
echo.
echo namespace %projectName%.Application.Commands.Products;
echo.
echo public record CreateProductCommand : IRequest^<ProductId^>
echo {
echo     public string Name { get; init; } = string.Empty;
echo     public decimal Price { get; init; }
echo     public string Currency { get; init; } = "USD";
echo     public string Description { get; init; } = string.Empty;
echo     public int InitialStock { get; init; }
echo }
echo.
echo public record UpdateProductPriceCommand : IRequest^<bool^>
echo {
echo     public int ProductId { get; init; }
echo     public decimal NewPrice { get; init; }
echo     public string Currency { get; init; } = "USD";
echo }
echo.
echo public record AddStockCommand : IRequest^<bool^>
echo {
echo     public int ProductId { get; init; }
echo     public int Quantity { get; init; }
echo }
echo.
echo public record RemoveStockCommand : IRequest^<bool^>
echo {
echo     public int ProductId { get; init; }
echo     public int Quantity { get; init; }
echo }
echo.
echo public record DeactivateProductCommand : IRequest^<bool^>
echo {
echo     public int ProductId { get; init; }
echo }
) > "%projectName%.Application\Commands\Products\ProductCommands.cs"

REM Validators
(
echo using FluentValidation;
echo.
echo namespace %projectName%.Application.Commands.Products;
echo.
echo public class CreateProductCommandValidator : AbstractValidator^<CreateProductCommand^>
echo {
echo     public CreateProductCommandValidator^(^)
echo     {
echo         RuleFor^(x =^> x.Name^).NotEmpty^(^).MaximumLength^(200^);
echo         RuleFor^(x =^> x.Price^).GreaterThan^(0^);
echo         RuleFor^(x =^> x.Currency^).NotEmpty^(^).MaximumLength^(3^);
echo         RuleFor^(x =^> x.InitialStock^).GreaterThanOrEqualTo^(0^);
echo     }
echo }
echo.
echo public class UpdateProductPriceCommandValidator : AbstractValidator^<UpdateProductPriceCommand^>
echo {
echo     public UpdateProductPriceCommandValidator^(^)
echo     {
echo         RuleFor^(x =^> x.ProductId^).GreaterThan^(0^).WithMessage^("ProductId must be ^> 0"^);
echo         RuleFor^(x =^> x.NewPrice^).GreaterThan^(0^).WithMessage^("Price must be ^> 0"^);
echo         RuleFor^(x =^> x.Currency^).NotEmpty^(^).MaximumLength^(3^);
echo     }
echo }
echo.
echo public class AddStockCommandValidator : AbstractValidator^<AddStockCommand^>
echo {
echo     public AddStockCommandValidator^(^)
echo     {
echo         RuleFor^(x =^> x.ProductId^).GreaterThan^(0^);
echo         RuleFor^(x =^> x.Quantity^).GreaterThan^(0^);
echo     }
echo }
echo.
echo public class RemoveStockCommandValidator : AbstractValidator^<RemoveStockCommand^>
echo {
echo     public RemoveStockCommandValidator^(^)
echo     {
echo         RuleFor^(x =^> x.ProductId^).GreaterThan^(0^);
echo         RuleFor^(x =^> x.Quantity^).GreaterThan^(0^);
echo     }
echo }
echo.
echo public class DeactivateProductCommandValidator : AbstractValidator^<DeactivateProductCommand^>
echo {
echo     public DeactivateProductCommandValidator^(^)
echo     {
echo         RuleFor^(x =^> x.ProductId^).GreaterThan^(0^);
echo     }
echo }
) > "%projectName%.Application\Commands\Products\ProductCommandValidators.cs"

REM Command Handlers

if "%cqrsMode%"=="Light" (
    (
echo using MediatR;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Application.Commands.Products;
echo.
echo public class CreateProductCommandHandler : IRequestHandler^<CreateProductCommand, ProductId^>
echo {
echo     private readonly IProductRepository _repository;
echo     private readonly IUnitOfWork _unitOfWork;
echo     private readonly IDomainEventDispatcher _eventDispatcher;
echo.
echo     public CreateProductCommandHandler^(IProductRepository repository, IUnitOfWork unitOfWork, IDomainEventDispatcher eventDispatcher^)
echo     {
echo         _repository = repository;
echo         _unitOfWork = unitOfWork;
echo         _eventDispatcher = eventDispatcher;
echo     }
echo.
echo     public async Task^<ProductId^> Handle^(CreateProductCommand request, CancellationToken ct^)
echo     {
echo         var product = new Product^(
echo             ProductId.Create^(^),
echo             request.Name,
echo             new Money^(request.Price, request.Currency^),
echo             request.Description,
echo             request.InitialStock^);
echo.
echo         await _repository.AddAsync^(product, ct^);
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(product.DomainEvents, ct^);
echo.
echo         return product.Id;
echo     }
echo }
echo.
echo public class UpdateProductPriceCommandHandler : IRequestHandler^<UpdateProductPriceCommand, bool^>
echo {
echo     private readonly IProductRepository _repository;
echo     private readonly IUnitOfWork _unitOfWork;
echo     private readonly IDomainEventDispatcher _eventDispatcher;
echo.
echo     public UpdateProductPriceCommandHandler^(IProductRepository repository, IUnitOfWork unitOfWork, IDomainEventDispatcher eventDispatcher^)
echo     {
echo         _repository = repository;
echo         _unitOfWork = unitOfWork;
echo         _eventDispatcher = eventDispatcher;
echo     }
echo.
echo     public async Task^<bool^> Handle^(UpdateProductPriceCommand request, CancellationToken ct^)
echo     {
echo         var product = await _repository.GetByIdAsync^(ProductId.From^(request.ProductId^), ct^);
echo         if ^(product == null^) return false;
echo.
echo         product.UpdatePrice^(new Money^(request.NewPrice, request.Currency^)^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(product.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo }
echo.
echo public class AddStockCommandHandler : IRequestHandler^<AddStockCommand, bool^>
echo {
echo     private readonly IProductRepository _repository;
echo     private readonly IUnitOfWork _unitOfWork;
echo     private readonly IDomainEventDispatcher _eventDispatcher;
echo.
echo     public AddStockCommandHandler^(IProductRepository repository, IUnitOfWork unitOfWork, IDomainEventDispatcher eventDispatcher^)
echo     {
echo         _repository = repository;
echo         _unitOfWork = unitOfWork;
echo         _eventDispatcher = eventDispatcher;
echo     }
echo.
echo     public async Task^<bool^> Handle^(AddStockCommand request, CancellationToken ct^)
echo     {
echo         var product = await _repository.GetByIdAsync^(ProductId.From^(request.ProductId^), ct^);
echo         if ^(product == null^) return false;
echo.
echo         product.AddStock^(request.Quantity^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(product.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo }
    ) > "%projectName%.Application\Commands\Products\ProductCommandHandlers.cs"
) else (
    (
echo using MediatR;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Application.Commands.Products;
echo.
echo public class CreateProductCommandHandler : IRequestHandler^<CreateProductCommand, ProductId^>
echo {
echo     private readonly IProductWriteRepository _repository;
echo     private readonly IUnitOfWork _unitOfWork;
echo     private readonly IDomainEventDispatcher _eventDispatcher;
echo.
echo     public CreateProductCommandHandler^(IProductWriteRepository repository, IUnitOfWork unitOfWork, IDomainEventDispatcher eventDispatcher^)
echo     {
echo         _repository = repository;
echo         _unitOfWork = unitOfWork;
echo         _eventDispatcher = eventDispatcher;
echo     }
echo.
echo     public async Task^<ProductId^> Handle^(CreateProductCommand request, CancellationToken ct^)
echo     {
echo         var product = new Product^(
echo             ProductId.Create^(^),
echo             request.Name,
echo             new Money^(request.Price, request.Currency^),
echo             request.Description,
echo             request.InitialStock^);
echo.
echo         await _repository.AddAsync^(product, ct^);
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(product.DomainEvents, ct^);
echo.
echo         return product.Id;
echo     }
echo }
echo.
echo public class UpdateProductPriceCommandHandler : IRequestHandler^<UpdateProductPriceCommand, bool^>
echo {
echo     private readonly IProductWriteRepository _repository;
echo     private readonly IUnitOfWork _unitOfWork;
echo     private readonly IDomainEventDispatcher _eventDispatcher;
echo.
echo     public UpdateProductPriceCommandHandler^(IProductWriteRepository repository, IUnitOfWork unitOfWork, IDomainEventDispatcher eventDispatcher^)
echo     {
echo         _repository = repository;
echo         _unitOfWork = unitOfWork;
echo         _eventDispatcher = eventDispatcher;
echo     }
echo.
echo     public async Task^<bool^> Handle^(UpdateProductPriceCommand request, CancellationToken ct^)
echo     {
echo         var product = await _repository.GetByIdAsync^(ProductId.From^(request.ProductId^), ct^);
echo         if ^(product == null^) return false;
echo.
echo         product.UpdatePrice^(new Money^(request.NewPrice, request.Currency^)^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(product.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo }
    ) > "%projectName%.Application\Commands\Products\ProductCommandHandlers.cs"
)
echo [DEBUG] ProductQueries.cs creado OK
REM ========== QUERIES EXTENDIDAS ==========
REM Queries

if "%cqrsMode%"=="Light" (
    (
echo using MediatR;
echo using %projectName%.Application.DTOs;
echo.
echo namespace %projectName%.Application.Queries.Products;
echo.
echo public record GetProductsQuery : IRequest^<IEnumerable^<ProductDto^>^>;
echo public record GetProductByIdQuery^(int Id^) : IRequest^<ProductDto?^>;
echo public record GetActiveProductsQuery : IRequest^<IEnumerable^<ProductDto^>^>;
echo public record GetProductsByPriceRangeQuery^(decimal MinPrice, decimal MaxPrice^) : IRequest^<IEnumerable^<ProductDto^>^>;
echo public record GetProductsInStockQuery : IRequest^<IEnumerable^<ProductDto^>^>;
    ) > "%projectName%.Application\Queries\Products\ProductQueries.cs"
) else (
    (
echo using MediatR;
echo using %projectName%.Application.ReadModels;
echo.
echo namespace %projectName%.Application.Queries.Products;
echo.
echo public record GetProductsQuery : IRequest^<IEnumerable^<ProductReadModel^>^>;
echo public record GetProductByIdQuery^(int Id^) : IRequest^<ProductReadModel?^>;
echo public record GetActiveProductsQuery : IRequest^<IEnumerable^<ProductReadModel^>^>;
echo public record GetProductsByPriceRangeQuery^(decimal MinPrice, decimal MaxPrice^) : IRequest^<IEnumerable^<ProductReadModel^>^>;
echo public record GetProductsInStockQuery : IRequest^<IEnumerable^<ProductReadModel^>^>;
    ) > "%projectName%.Application\Queries\Products\ProductQueries.cs"
)
echo [DEBUG] Creando ProductQueries.cs...
REM Query Validators
(
echo using FluentValidation;
echo.
echo namespace %projectName%.Application.Queries.Products;
echo.
echo public class GetProductByIdQueryValidator : AbstractValidator^<GetProductByIdQuery^>
echo {
echo     public GetProductByIdQueryValidator^(^)
echo     {
echo         RuleFor^(x =^> x.Id^)
echo             .GreaterThan^(0^)
echo             .WithMessage^("ProductId must be greater than 0"^);
echo     }
echo }
echo.
echo public class GetProductsByPriceRangeQueryValidator : AbstractValidator^<GetProductsByPriceRangeQuery^>
echo {
echo     public GetProductsByPriceRangeQueryValidator^(^)
echo     {
echo         RuleFor^(x =^> x.MinPrice^)
echo             .GreaterThanOrEqualTo^(0^)
echo             .WithMessage^("MinPrice cannot be negative"^);
echo.
echo         RuleFor^(x =^> x.MaxPrice^)
echo             .GreaterThan^(x =^> x.MinPrice^)
echo             .WithMessage^("MaxPrice must be greater than MinPrice"^);
echo     }
echo }
) > "%projectName%.Application\Queries\Products\ProductQueryValidators.cs"
echo [DEBUG] ProductQueryValidators.cs creado OK
REM Query Handlers segun modo ********************************
echo Query Handlers segun modo
if "%cqrsMode%"=="Light" (
    (
echo using AutoMapper;
echo using MediatR;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.DTOs;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo.
echo namespace %projectName%.Application.Queries.Products;
echo.
echo public class GetProductsQueryHandler : IRequestHandler^<GetProductsQuery, IEnumerable^<ProductDto^>^>
echo {
echo     private readonly IProductRepository _repository;
echo     private readonly IMapper _mapper;
echo.
echo     public GetProductsQueryHandler^(IProductRepository repository, IMapper mapper^)
echo     {
echo         _repository = repository;
echo         _mapper = mapper;
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductDto^>^> Handle^(GetProductsQuery request, CancellationToken ct^)
echo     {
echo         var products = await _repository.GetAllAsync^(ct^);
echo         return _mapper.Map^<IEnumerable^<ProductDto^>^>^(products^);
echo     }
echo }
echo.
echo public class GetProductByIdQueryHandler : IRequestHandler^<GetProductByIdQuery, ProductDto?^>
echo {
echo     private readonly IProductRepository _repository;
echo     private readonly IMapper _mapper;
echo.
echo     public GetProductByIdQueryHandler^(IProductRepository repository, IMapper mapper^)
echo     {
echo         _repository = repository;
echo         _mapper = mapper;
echo     }
echo.
echo     public async Task^<ProductDto?^> Handle^(GetProductByIdQuery request, CancellationToken ct^)
echo     {
echo         var product = await _repository.GetByIdAsync^(ProductId.From^(request.Id^), ct^);
echo         return product == null ? null : _mapper.Map^<ProductDto^>^(product^);
echo     }
echo }
echo.
echo public class GetActiveProductsQueryHandler : IRequestHandler^<GetActiveProductsQuery, IEnumerable^<ProductDto^>^>
echo {
echo     private readonly IProductRepository _repository;
echo     private readonly IMapper _mapper;
echo.
echo     public GetActiveProductsQueryHandler^(IProductRepository repository, IMapper mapper^)
echo     {
echo         _repository = repository;
echo         _mapper = mapper;
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductDto^>^> Handle^(GetActiveProductsQuery request, CancellationToken ct^)
echo     {
echo         var products = await _repository.FindAsync^(new ActiveProductsSpecification^(^), ct^);
echo         return _mapper.Map^<IEnumerable^<ProductDto^>^>^(products^);
echo     }
echo }
echo.
echo public class GetProductsByPriceRangeQueryHandler : IRequestHandler^<GetProductsByPriceRangeQuery, IEnumerable^<ProductDto^>^>
echo {
echo     private readonly IProductRepository _repository;
echo     private readonly IMapper _mapper;
echo.
echo     public GetProductsByPriceRangeQueryHandler^(IProductRepository repository, IMapper mapper^)
echo     {
echo         _repository = repository;
echo         _mapper = mapper;
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductDto^>^> Handle^(GetProductsByPriceRangeQuery request, CancellationToken ct^)
echo     {
echo         var spec = new ProductsByPriceRangeSpecification^(request.MinPrice, request.MaxPrice^);
echo         var products = await _repository.FindAsync^(spec, ct^);
echo         return _mapper.Map^<IEnumerable^<ProductDto^>^>^(products^);
echo     }
echo }
echo.
echo public class GetProductsInStockQueryHandler : IRequestHandler^<GetProductsInStockQuery, IEnumerable^<ProductDto^>^>
echo {
echo     private readonly IProductRepository _repository;
echo     private readonly IMapper _mapper;
echo.
echo     public GetProductsInStockQueryHandler^(IProductRepository repository, IMapper mapper^)
echo     {
echo         _repository = repository;
echo         _mapper = mapper;
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductDto^>^> Handle^(GetProductsInStockQuery request, CancellationToken ct^)
echo     {
echo         var products = await _repository.FindAsync^(new ProductsInStockSpecification^(^), ct^);
echo         return _mapper.Map^<IEnumerable^<ProductDto^>^>^(products^);
echo     }
echo }
    ) > "%projectName%.Application\Queries\Products\ProductQueryHandlers.cs"
) else (
    REM Query Handlers para CQRS Real con EF ***************************************************
    if "%useDapper%"=="false" (
        (
echo using MediatR;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.ReadModels;
echo.
echo namespace %projectName%.Application.Queries.Products;
echo.
echo public class GetProductsQueryHandler : IRequestHandler^<GetProductsQuery, IEnumerable^<ProductReadModel^>^>
echo {
echo     private readonly IProductReadRepository _repository;
echo.
echo     public GetProductsQueryHandler^(IProductReadRepository repository^)
echo     {
echo         _repository = repository;
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductReadModel^>^> Handle^(GetProductsQuery request, CancellationToken ct^)
echo     {
echo         return await _repository.GetAllAsync^(ct^);
echo     }
echo }
echo.
echo public class GetProductByIdQueryHandler : IRequestHandler^<GetProductByIdQuery, ProductReadModel?^>
echo {
echo     private readonly IProductReadRepository _repository;
echo.
echo     public GetProductByIdQueryHandler^(IProductReadRepository repository^)
echo     {
echo         _repository = repository;
echo     }
echo.
echo     public async Task^<ProductReadModel?^> Handle^(GetProductByIdQuery request, CancellationToken ct^)
echo     {
echo         return await _repository.GetByIdAsync^(request.Id, ct^);
echo     }
echo }
echo.
echo public class GetActiveProductsQueryHandler : IRequestHandler^<GetActiveProductsQuery, IEnumerable^<ProductReadModel^>^>
echo {
echo     private readonly IProductReadRepository _repository;
echo.
echo     public GetActiveProductsQueryHandler^(IProductReadRepository repository^)
echo     {
echo         _repository = repository;
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductReadModel^>^> Handle^(GetActiveProductsQuery request, CancellationToken ct^)
echo     {
echo         return await _repository.FindAsync^(p =^> p.IsActive, ct^);
echo     }
echo }
echo.
echo public class GetProductsByPriceRangeQueryHandler : IRequestHandler^<GetProductsByPriceRangeQuery, IEnumerable^<ProductReadModel^>^>
echo {
echo     private readonly IProductReadRepository _repository;
echo.
echo     public GetProductsByPriceRangeQueryHandler^(IProductReadRepository repository^)
echo     {
echo         _repository = repository;
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductReadModel^>^> Handle^(GetProductsByPriceRangeQuery request, CancellationToken ct^)
echo     {
echo         return await _repository.FindAsync^(
echo             p =^> p.Price ^>= request.MinPrice ^&^& p.Price ^<= request.MaxPrice, 
echo             ct^);
echo     }
echo }
echo.
echo public class GetProductsInStockQueryHandler : IRequestHandler^<GetProductsInStockQuery, IEnumerable^<ProductReadModel^>^>
echo {
echo     private readonly IProductReadRepository _repository;
echo.
echo     public GetProductsInStockQueryHandler^(IProductReadRepository repository^)
echo     {
echo         _repository = repository;
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductReadModel^>^> Handle^(GetProductsInStockQuery request, CancellationToken ct^)
echo     {
echo         return await _repository.FindAsync^(p =^> p.Stock ^> 0, ct^);
echo     }
echo }
    ) > "%projectName%.Application\Queries\Products\ProductQueryHandlers.cs"
    )
    if "%useDapper%"=="true" (
        REM Query Handlers para CQRS Real con Dapper (IQueryService) ****************************
        (
echo using MediatR;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.ReadModels;
echo.
echo namespace %projectName%.Application.Queries.Products;
echo.
echo public class GetProductsQueryHandler : IRequestHandler^<GetProductsQuery, IEnumerable^<ProductReadModel^>^>
echo {
echo     private readonly IQueryService _queryService;
echo.
echo     public GetProductsQueryHandler^(IQueryService queryService^)
echo     {
echo         _queryService = queryService;
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductReadModel^>^> Handle^(GetProductsQuery request, CancellationToken ct^)
echo     {
echo         const string sql = "SELECT * FROM ProductsReadModel ORDER BY CreatedAt DESC";
echo         return await _queryService.QueryAsync^<ProductReadModel^>^(sql, null, ct^);
echo     }
echo }
echo.
echo public class GetProductByIdQueryHandler : IRequestHandler^<GetProductByIdQuery, ProductReadModel?^>
echo {
echo     private readonly IQueryService _queryService;
echo.
echo     public GetProductByIdQueryHandler^(IQueryService queryService^)
echo     {
echo         _queryService = queryService;
echo     }
echo.
echo     public async Task^<ProductReadModel?^> Handle^(GetProductByIdQuery request, CancellationToken ct^)
echo     {
echo         const string sql = "SELECT * FROM ProductsReadModel WHERE Id = @Id";
echo         return await _queryService.QuerySingleAsync^<ProductReadModel^>^(sql, new { Id = request.Id }, ct^);
echo     }
echo }
echo.
echo public class GetActiveProductsQueryHandler : IRequestHandler^<GetActiveProductsQuery, IEnumerable^<ProductReadModel^>^>
echo {
echo     private readonly IQueryService _queryService;
echo.
echo     public GetActiveProductsQueryHandler^(IQueryService queryService^)
echo     {
echo         _queryService = queryService;
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductReadModel^>^> Handle^(GetActiveProductsQuery request, CancellationToken ct^)
echo     {
echo         const string sql = "SELECT * FROM ProductsReadModel WHERE IsActive = 1 ORDER BY Name";
echo         return await _queryService.QueryAsync^<ProductReadModel^>^(sql, null, ct^);
echo     }
echo }
echo.
echo public class GetProductsByPriceRangeQueryHandler : IRequestHandler^<GetProductsByPriceRangeQuery, IEnumerable^<ProductReadModel^>^>
echo {
echo     private readonly IQueryService _queryService;
echo.
echo     public GetProductsByPriceRangeQueryHandler^(IQueryService queryService^)
echo     {
echo         _queryService = queryService;
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductReadModel^>^> Handle^(GetProductsByPriceRangeQuery request, CancellationToken ct^)
echo     {
echo         const string sql = @"SELECT * FROM ProductsReadModel WHERE Price ^>= @MinPrice AND Price ^<= @MaxPrice ORDER BY Price";
echo         return await _queryService.QueryAsync^<ProductReadModel^>^(
echo             sql, 
echo             new { MinPrice = request.MinPrice, MaxPrice = request.MaxPrice }, 
echo             ct^);
echo     }
echo }
echo.
echo public class GetProductsInStockQueryHandler : IRequestHandler^<GetProductsInStockQuery, IEnumerable^<ProductReadModel^>^>
echo {
echo     private readonly IQueryService _queryService;
echo.
echo     public GetProductsInStockQueryHandler^(IQueryService queryService^)
echo     {
echo         _queryService = queryService;
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductReadModel^>^> Handle^(GetProductsInStockQuery request, CancellationToken ct^)
echo     {
echo         const string sql = "SELECT * FROM ProductsReadModel WHERE Stock ^> 0 ORDER BY Stock DESC";
echo         return await _queryService.QueryAsync^<ProductReadModel^>^(sql, null, ct^);
echo     }
echo }
    ) > "%projectName%.Application\Queries\Products\ProductQueryHandlers.cs"
    )
)
REM ========== DTOs ==========
(
echo namespace %projectName%.Application.DTOs;
echo.
echo public class ProductDto
echo {
echo     public int Id { get; set; }
echo     public string Name { get; set; } = string.Empty;
echo     public decimal Price { get; set; }
echo     public string Currency { get; set; } = "USD";
echo     public string Description { get; set; } = string.Empty;
echo     public bool IsActive { get; set; }
echo     public int Stock { get; set; }
echo     public DateTime CreatedAt { get; set; }
echo }
echo.
echo public class CustomerDto
echo {
echo     public int Id { get; set; }
echo     public string FirstName { get; set; } = string.Empty;
echo     public string LastName { get; set; } = string.Empty;
echo     public string FullName { get; set; } = string.Empty;
echo     public string Email { get; set; } = string.Empty;
echo     public bool IsActive { get; set; }
echo }
) > "%projectName%.Application\DTOs\DTOs.cs"

REM ========== AUTOMAPPER ==========

(
echo using AutoMapper;
echo using %projectName%.Application.DTOs;
echo using %projectName%.Domain.Entities;
echo.
echo namespace %projectName%.Application.Common.Mappings;
echo.
echo public class MappingProfile : Profile
echo {
echo     public MappingProfile^(^)
echo     {
echo         CreateMap^<Product, ProductDto^>^(^)
echo             .ForMember^(d =^> d.Id, o =^> o.MapFrom^(s =^> s.Id.Value^)^)
echo             .ForMember^(d =^> d.Price, o =^> o.MapFrom^(s =^> s.Price.Amount^)^)
echo             .ForMember^(d =^> d.Currency, o =^> o.MapFrom^(s =^> s.Price.Currency^)^);
echo.
echo         CreateMap^<Customer, CustomerDto^>^(^)
echo             .ForMember^(d =^> d.Id, o =^> o.MapFrom^(s =^> s.Id.Value^)^)
echo             .ForMember^(d =^> d.Email, o =^> o.MapFrom^(s =^> s.Email.Address^)^)
echo             .ForMember^(d =^> d.FullName, o =^> o.MapFrom^(s =^> s.GetFullName^(^)^)^);
echo     }
echo }
) > "%projectName%.Application\Common\Mappings\MappingProfile.cs"

REM ========== BEHAVIORS ==========

(
echo using FluentValidation;
echo using MediatR;
echo.
echo namespace %projectName%.Application.Common.Behaviors;
echo.
echo public class ValidationBehavior^<TRequest, TResponse^> : IPipelineBehavior^<TRequest, TResponse^>
echo     where TRequest : IRequest^<TResponse^>
echo {
echo     private readonly IEnumerable^<IValidator^<TRequest^>^> _validators;
echo.
echo     public ValidationBehavior^(IEnumerable^<IValidator^<TRequest^>^> validators^) =^> _validators = validators;
echo.
echo     public async Task^<TResponse^> Handle^(TRequest request, RequestHandlerDelegate^<TResponse^> next, CancellationToken ct^)
echo     {
echo         if ^(_validators.Any^(^)^)
echo         {
echo             var context = new ValidationContext^<TRequest^>^(request^);
echo             var results = await Task.WhenAll^(_validators.Select^(v =^> v.ValidateAsync^(context, ct^)^)^);
echo             var failures = results.SelectMany^(r =^> r.Errors^).Where^(f =^> f != null^).ToList^(^);
echo.
echo             if ^(failures.Any^(^)^)
echo                 throw new ValidationException^(failures^);
echo         }
echo         return await next^(^);
echo     }
echo }
) > "%projectName%.Application\Common\Behaviors\ValidationBehavior.cs"

REM ========== PROJECTIONS ==========

if NOT "%cqrsMode%"=="Light" (
    (
echo using MediatR;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.ReadModels;
echo using %projectName%.Domain.Events;
echo.
echo namespace %projectName%.Application.Projections;
echo.
echo public class ProductCreatedProjection : INotificationHandler^<ProductCreatedEvent^>
echo {
echo     private readonly IProjectionWriter^<ProductReadModel^> _writer;
echo.
echo     public ProductCreatedProjection^(IProjectionWriter^<ProductReadModel^> writer^) =^> _writer = writer;
echo.
echo     public async Task Handle^(ProductCreatedEvent evt, CancellationToken ct^)
echo     {
echo         var model = new ProductReadModel
echo         {
echo             Id = evt.Product.Id.Value,
echo             Name = evt.Product.Name,
echo             Price = evt.Product.Price.Amount,
echo             Currency = evt.Product.Price.Currency,
echo             Description = evt.Product.Description,
echo             IsActive = evt.Product.IsActive,
echo             Stock = evt.Product.Stock,
echo             CreatedAt = evt.Product.CreatedAt
echo         };
echo.
echo         await _writer.InsertAsync^(model, ct^);
echo     }
echo }
echo.
echo public class ProductPriceChangedProjection : INotificationHandler^<ProductPriceChangedEvent^>
echo {
echo     private readonly IProjectionWriter^<ProductReadModel^> _writer;
echo.
echo     public ProductPriceChangedProjection^(IProjectionWriter^<ProductReadModel^> writer^) =^> _writer = writer;
echo.
echo     public async Task Handle^(ProductPriceChangedEvent evt, CancellationToken ct^)
echo     {
echo         var model = await _writer.GetByIdAsync^(evt.Product.Id.Value, ct^);
echo         if ^(model != null^)
echo         {
echo             model.Price = evt.NewPrice.Amount;
echo             model.Currency = evt.NewPrice.Currency;
echo             model.UpdatedAt = DateTime.UtcNow;
echo             await _writer.UpdateAsync^(model, ct^);
echo         }
echo     }
echo }
echo.
echo public class StockAddedProjection : INotificationHandler^<StockAddedEvent^>
echo {
echo     private readonly IProjectionWriter^<ProductReadModel^> _writer;
echo.
echo     public StockAddedProjection^(IProjectionWriter^<ProductReadModel^> writer^) =^> _writer = writer;
echo.
echo     public async Task Handle^(StockAddedEvent evt, CancellationToken ct^)
echo     {
echo         var model = await _writer.GetByIdAsync^(evt.Product.Id.Value, ct^);
echo         if ^(model != null^)
echo         {
echo             model.Stock = evt.Product.Stock;
echo             model.UpdatedAt = DateTime.UtcNow;
echo             await _writer.UpdateAsync^(model, ct^);
echo         }
echo     }
echo }
    ) > "%projectName%.Application\Projections\ProductProjections.cs"
)

REM ========== DEPENDENCY INJECTION APPLICATION ==========

(
echo using System.Reflection;
echo using FluentValidation;
echo using MediatR;
echo using Microsoft.Extensions.DependencyInjection;
echo using %projectName%.Application.Common.Behaviors;
echo.
echo namespace %projectName%.Application;
echo.
echo public static class DependencyInjection
echo {
echo     public static IServiceCollection AddApplication^(this IServiceCollection services^)
echo     {
echo         var assembly = Assembly.GetExecutingAssembly^(^);
echo.
echo         services.AddMediatR^(cfg =^> cfg.RegisterServicesFromAssembly^(assembly^)^);
echo         services.AddValidatorsFromAssembly^(assembly^);
echo         services.AddAutoMapper^(assembly^);
echo.
echo         services.AddTransient^(typeof^(IPipelineBehavior^<,^>^), typeof^(ValidationBehavior^<,^>^)^);
echo.
echo         return services;
echo     }
echo }
) > "%projectName%.Application\DependencyInjection.cs"

echo.
echo ============================================================
echo === CREANDO INFRASTRUCTURE LAYER ===
echo ============================================================
mkdir "%projectName%.Infrastructure\Persistence\Configurations"
mkdir "%projectName%.Infrastructure\Persistence\Repositories"
mkdir "%projectName%.Infrastructure\EventSourcing"
mkdir "%projectName%.Infrastructure\Services"

if NOT "%cqrsMode%"=="Light" (
    mkdir "%projectName%.Infrastructure\Persistence\ReadModels"
    if "%useDapper%"=="true" (
        mkdir "%projectName%.Infrastructure\Persistence\Queries"
    )
)

REM ========== EF CONFIGURATIONS ==========

(
echo using Microsoft.EntityFrameworkCore;
echo using Microsoft.EntityFrameworkCore.Metadata.Builders;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo.
echo namespace %projectName%.Infrastructure.Persistence.Configurations;
echo.
echo public class ProductConfiguration : IEntityTypeConfiguration^<Product^>
echo {
echo     public void Configure^(EntityTypeBuilder^<Product^> builder^)
echo     {
echo         builder.ToTable^("Products"^);
echo         builder.HasKey^(p =^> p.Id^);
echo.
echo         builder.Property^(p =^> p.Id^)
echo             .HasConversion^(id =^> id.Value, value =^> ProductId.From^(value^)^)
echo             .ValueGeneratedOnAdd^(^);
echo.
echo         builder.Property^(p =^> p.Name^).IsRequired^(^).HasMaxLength^(200^);
echo         builder.Property^(p =^> p.Description^).HasMaxLength^(1000^);
echo.
echo         builder.OwnsOne^(p =^> p.Price, price =^>
echo         {
echo             price.Property^(m =^> m.Amount^).HasColumnName^("Price"^).HasColumnType^("decimal(18,2)"^);
echo             price.Property^(m =^> m.Currency^).HasColumnName^("Currency"^).HasMaxLength^(3^);
echo         }^);
echo.
echo         builder.Ignore^(p =^> p.DomainEvents^);
echo     }
echo }
) > "%projectName%.Infrastructure\Persistence\Configurations\ProductConfiguration.cs"

(
echo using Microsoft.EntityFrameworkCore;
echo using Microsoft.EntityFrameworkCore.Metadata.Builders;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo.
echo namespace %projectName%.Infrastructure.Persistence.Configurations;
echo.
echo public class CustomerConfiguration : IEntityTypeConfiguration^<Customer^>
echo {
echo     public void Configure^(EntityTypeBuilder^<Customer^> builder^)
echo     {
echo         builder.ToTable^("Customers"^);
echo         builder.HasKey^(c =^> c.Id^);
echo.
echo         builder.Property^(c =^> c.Id^)
echo             .HasConversion^(id =^> id.Value, value =^> CustomerId.From^(value^)^)
echo             .ValueGeneratedOnAdd^(^);
echo.
echo         builder.Property^(c =^> c.FirstName^).IsRequired^(^).HasMaxLength^(100^);
echo         builder.Property^(c =^> c.LastName^).IsRequired^(^).HasMaxLength^(100^);
echo.
echo         builder.OwnsOne^(c =^> c.Email, email =^>
echo             email.Property^(e =^> e.Address^).HasColumnName^("Email"^).IsRequired^(^).HasMaxLength^(256^)^);
echo.
echo         builder.Ignore^(c =^> c.DomainEvents^);
echo     }
echo }
) > "%projectName%.Infrastructure\Persistence\Configurations\CustomerConfiguration.cs"

(
echo using Microsoft.EntityFrameworkCore;
echo using Microsoft.EntityFrameworkCore.Metadata.Builders;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo.
echo namespace %projectName%.Infrastructure.Persistence.Configurations;
echo.
echo public class OrderConfiguration : IEntityTypeConfiguration^<Order^>
echo {
echo     public void Configure^(EntityTypeBuilder^<Order^> builder^)
echo     {
echo         builder.ToTable^("Orders"^);
echo         builder.HasKey^(o =^> o.Id^);
echo.
echo         builder.Property^(o =^> o.Id^)
echo             .HasConversion^(id =^> id.Value, value =^> OrderId.From^(value^)^)
echo             .ValueGeneratedOnAdd^(^);
echo.
echo         builder.Property^(o =^> o.CustomerId^)
echo             .HasConversion^(id =^> id.Value, value =^> CustomerId.From^(value^)^);
echo.
echo         builder.HasOne^<Customer^>^(^).WithMany^(^).HasForeignKey^(o =^> o.CustomerId^).OnDelete^(DeleteBehavior.Restrict^);
echo.
echo         builder.OwnsMany^(o =^> o.Items, items =^>
echo         {
echo             items.ToTable^("OrderItems"^);
echo             items.WithOwner^(^).HasForeignKey^("OrderId"^);
echo             items.HasKey^(i =^> i.Id^);
echo.
echo             items.Property^(i =^> i.Id^)
echo                 .HasConversion^(id =^> id.Value, value =^> OrderItemId.From^(value^)^)
echo                 .ValueGeneratedOnAdd^(^);
echo.
echo             items.Property^(i =^> i.ProductId^)
echo                 .HasConversion^(id =^> id.Value, value =^> ProductId.From^(value^)^);
echo.
echo             items.OwnsOne^(i =^> i.UnitPrice, price =^>
echo             {
echo                 price.Property^(m =^> m.Amount^).HasColumnName^("UnitPrice"^).HasColumnType^("decimal(18,2)"^);
echo                 price.Property^(m =^> m.Currency^).HasColumnName^("Currency"^).HasMaxLength^(3^);
echo             }^);
echo         }^);
echo.
echo         builder.Property^(o =^> o.Status^).HasConversion^<string^>^(^);
echo         builder.Ignore^(o =^> o.DomainEvents^);
echo     }
echo }
) > "%projectName%.Infrastructure\Persistence\Configurations\OrderConfiguration.cs"

REM ========== DB CONTEXTS ==========

if "%cqrsMode%"=="Light" (
    (
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Domain.Entities;
echo.
echo namespace %projectName%.Infrastructure.Persistence;
echo.
echo public class ApplicationDbContext : DbContext
echo {
echo     public DbSet^<Product^> Products { get; set; } = null!;
echo     public DbSet^<Customer^> Customers { get; set; } = null!;
echo     public DbSet^<Order^> Orders { get; set; } = null!;
echo.
echo     public ApplicationDbContext^(DbContextOptions^<ApplicationDbContext^> options^) : base^(options^) { }
echo.
echo     protected override void OnModelCreating^(ModelBuilder modelBuilder^)
echo     {
echo         modelBuilder.ApplyConfigurationsFromAssembly^(typeof^(ApplicationDbContext^).Assembly^);
echo         base.OnModelCreating^(modelBuilder^);
echo     }
echo }
    ) > "%projectName%.Infrastructure\Persistence\ApplicationDbContext.cs"
) else (
    (
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Domain.Entities;
echo.
echo namespace %projectName%.Infrastructure.Persistence;
echo.
echo public class WriteDbContext : DbContext
echo {
echo     public DbSet^<Product^> Products { get; set; } = null!;
echo     public DbSet^<Customer^> Customers { get; set; } = null!;
echo     public DbSet^<Order^> Orders { get; set; } = null!;
echo.
echo     public WriteDbContext^(DbContextOptions^<WriteDbContext^> options^) : base^(options^) { }
echo.
echo     protected override void OnModelCreating^(ModelBuilder modelBuilder^)
echo     {
echo         modelBuilder.ApplyConfigurationsFromAssembly^(typeof^(WriteDbContext^).Assembly^);
echo         base.OnModelCreating^(modelBuilder^);
echo     }
echo }
    ) > "%projectName%.Infrastructure\Persistence\WriteDbContext.cs"
)
if "%cqrsMode%"=="RealEF" (
    (
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Application.ReadModels;
echo.
echo namespace %projectName%.Infrastructure.Persistence;
echo.
echo public class ReadDbContext : DbContext
echo {
echo     public DbSet^<ProductReadModel^> Products { get; set; } = null!;
echo     public DbSet^<CustomerReadModel^> Customers { get; set; } = null!;
echo     public DbSet^<OrderReadModel^> Orders { get; set; } = null!;
echo.
echo     public ReadDbContext^(DbContextOptions^<ReadDbContext^> options^) : base^(options^) { }
echo.
echo     protected override void OnModelCreating^(ModelBuilder modelBuilder^)
echo     {
echo         modelBuilder.Entity^<ProductReadModel^>^(e =^>
echo         {
echo             e.ToTable^("ProductsReadModel"^);
echo             e.HasKey^(p =^> p.Id^);
echo             e.HasIndex^(p =^> p.IsActive^);
echo         }^);
echo.
echo         modelBuilder.Entity^<CustomerReadModel^>^(e =^>
echo         {
echo             e.ToTable^("CustomersReadModel"^);
echo             e.HasKey^(c =^> c.Id^);
echo         }^);
echo.
echo         modelBuilder.Entity^<OrderReadModel^>^(e =^>
echo         {
echo             e.ToTable^("OrdersReadModel"^);
echo             e.HasKey^(o =^> o.Id^);
echo         }^);
echo     }
echo }
    ) > "%projectName%.Infrastructure\Persistence\ReadDbContext.cs"
)


REM ========== REPOSITORIES ==========

if "%cqrsMode%"=="Light" (
    (
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.Specifications;
echo.
echo namespace %projectName%.Infrastructure.Persistence.Repositories;
echo.
echo public class Repository^<T, TId^> : IRepository^<T, TId^>
echo     where T : AggregateRoot^<TId^> where TId : class
echo {
echo     protected readonly ApplicationDbContext _context;
echo     protected readonly DbSet^<T^> _dbSet;
echo.
echo     public Repository^(ApplicationDbContext context^)
echo     {
echo         _context = context;
echo         _dbSet = context.Set^<T^>^(^);
echo     }
echo.
echo     public virtual async Task^<T?^> GetByIdAsync^(TId id, CancellationToken ct = default^)
echo         =^> await _dbSet.FindAsync^(new object[] { id }, ct^);
echo.
echo     public virtual async Task^<IEnumerable^<T^>^> GetAllAsync^(CancellationToken ct = default^)
echo         =^> await _dbSet.ToListAsync^(ct^);
echo.
echo     public virtual async Task^<IEnumerable^<T^>^> FindAsync^(ISpecification^<T^> spec, CancellationToken ct = default^)
echo         =^> await _dbSet.Where^(spec.Criteria^).ToListAsync^(ct^);
echo.
echo     public virtual async Task^<T^> AddAsync^(T entity, CancellationToken ct = default^)
echo     {
echo         await _dbSet.AddAsync^(entity, ct^);
echo         return entity;
echo     }
echo.
echo     public virtual Task UpdateAsync^(T entity, CancellationToken ct = default^)
echo     {
echo         _dbSet.Update^(entity^);
echo         return Task.CompletedTask;
echo     }
echo.
echo     public virtual Task DeleteAsync^(T entity, CancellationToken ct = default^)
echo     {
echo         _dbSet.Remove^(entity^);
echo         return Task.CompletedTask;
echo     }
echo }
echo.
echo public class ProductRepository : Repository^<Product, ProductId^>, IProductRepository
echo {
echo     public ProductRepository^(ApplicationDbContext context^) : base^(context^) { }
echo }
echo.
echo public class CustomerRepository : Repository^<Customer, CustomerId^>, ICustomerRepository
echo {
echo     public CustomerRepository^(ApplicationDbContext context^) : base^(context^) { }
echo }
echo.
echo public class OrderRepository : Repository^<Order, OrderId^>, IOrderRepository
echo {
echo     public OrderRepository^(ApplicationDbContext context^) : base^(context^) { }
echo.
echo     public async Task^<IEnumerable^<Order^>^> GetOrdersByCustomerAsync^(CustomerId customerId, CancellationToken ct = default^)
echo         =^> await _dbSet.Where^(o =^> o.CustomerId == customerId^).ToListAsync^(ct^);
echo }
    ) > "%projectName%.Infrastructure\Persistence\Repositories\Repositories.cs"
) else (
    (
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo.
echo namespace %projectName%.Infrastructure.Persistence.Repositories;
echo.
echo public class WriteRepository^<T, TId^> : IWriteRepository^<T, TId^>
echo     where T : AggregateRoot^<TId^> where TId : class
echo {
echo     protected readonly WriteDbContext _context;
echo     protected readonly DbSet^<T^> _dbSet;
echo.
echo     public WriteRepository^(WriteDbContext context^)
echo     {
echo         _context = context;
echo         _dbSet = context.Set^<T^>^(^);
echo     }
echo.
echo     public virtual async Task^<T?^> GetByIdAsync^(TId id, CancellationToken ct = default^)
echo         =^> await _dbSet.FindAsync^(new object[] { id }, ct^);
echo.
echo     public virtual async Task^<T^> AddAsync^(T entity, CancellationToken ct = default^)
echo     {
echo         await _dbSet.AddAsync^(entity, ct^);
echo         return entity;
echo     }
echo.
echo     public virtual Task UpdateAsync^(T entity, CancellationToken ct = default^)
echo     {
echo         _dbSet.Update^(entity^);
echo         return Task.CompletedTask;
echo     }
echo.
echo     public virtual Task DeleteAsync^(T entity, CancellationToken ct = default^)
echo     {
echo         _dbSet.Remove^(entity^);
echo         return Task.CompletedTask;
echo     }
echo }
echo.
echo public class ProductWriteRepository : WriteRepository^<Product, ProductId^>, IProductWriteRepository
echo {
echo     public ProductWriteRepository^(WriteDbContext context^) : base^(context^) { }
echo }
echo.
echo public class CustomerWriteRepository : WriteRepository^<Customer, CustomerId^>, ICustomerWriteRepository
echo {
echo     public CustomerWriteRepository^(WriteDbContext context^) : base^(context^) { }
echo }
echo.
echo public class OrderWriteRepository : WriteRepository^<Order, OrderId^>, IOrderWriteRepository
echo {
echo     public OrderWriteRepository^(WriteDbContext context^) : base^(context^) { }
echo }
    ) > "%projectName%.Infrastructure\Persistence\Repositories\WriteRepositories.cs"
REM Repositories de lectura con Dapper o EF

if "%useDapper%"=="true" (
        (
echo using Dapper;
echo using Microsoft.Data.SqlClient;
echo using Microsoft.Extensions.Configuration;
echo using %projectName%.Application.Common.Interfaces;
echo.
echo namespace %projectName%.Infrastructure.Persistence.Queries;
echo.
echo public class DapperQueryService : IQueryService
echo {
echo     private readonly string _connectionString;
echo.
echo     public DapperQueryService^(IConfiguration configuration^)
echo         =^> _connectionString = configuration.GetConnectionString^("ReadConnection"^)!;
echo.
echo     public async Task^<T?^> QuerySingleAsync^<T^>^(string sql, object? parameters = null, CancellationToken ct = default^)
echo     {
echo         using var connection = new SqlConnection^(_connectionString^);
echo         return await connection.QuerySingleOrDefaultAsync^<T^>^(sql, parameters^);
echo     }
echo.
echo     public async Task^<IEnumerable^<T^>^> QueryAsync^<T^>^(string sql, object? parameters = null, CancellationToken ct = default^)
echo     {
echo         using var connection = new SqlConnection^(_connectionString^);
echo         return await connection.QueryAsync^<T^>^(sql, parameters^);
echo     }
echo.
echo     public async Task^<int^> ExecuteAsync^(string sql, object? parameters = null, CancellationToken ct = default^)
echo     {
echo         using var connection = new SqlConnection^(_connectionString^);
echo         return await connection.ExecuteAsync^(sql, parameters^);
echo     }
echo }
    ) > "%projectName%.Infrastructure\Persistence\Queries\DapperQueryService.cs"
        
        (
echo using Dapper;
echo using Microsoft.Data.SqlClient;
echo using Microsoft.Extensions.Configuration;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.ReadModels;
echo.
echo namespace %projectName%.Infrastructure.Persistence.ReadModels;
echo.
echo public class ProductProjectionWriter : IProjectionWriter^<ProductReadModel^>
echo {
echo     private readonly string _connectionString;
echo.
echo     public ProductProjectionWriter^(IConfiguration configuration^)
echo         =^> _connectionString = configuration.GetConnectionString^("ReadConnection"^)!;
echo.
echo     public async Task InsertAsync^(ProductReadModel model, CancellationToken ct = default^)
echo     {
echo         const string sql = @"INSERT INTO ProductsReadModel ^(Id, Name, Price, Currency, Description, IsActive, Stock, CreatedAt^) VALUES ^(@Id, @Name, @Price, @Currency, @Description, @IsActive, @Stock, @CreatedAt^)";
echo         using var conn = new SqlConnection^(_connectionString^);
echo         await conn.ExecuteAsync^(sql, model^);
echo     }
echo.
echo     public async Task UpdateAsync^(ProductReadModel model, CancellationToken ct = default^)
echo     {
echo         const string sql = @"UPDATE ProductsReadModel SET Name=@Name, Price=@Price, Currency=@Currency, Description=@Description, IsActive=@IsActive, Stock=@Stock, UpdatedAt=@UpdatedAt WHERE Id=@Id";
echo         using var conn = new SqlConnection^(_connectionString^);
echo         await conn.ExecuteAsync^(sql, model^);
echo     }
echo.
echo     public async Task DeleteAsync^(int id, CancellationToken ct = default^)
echo     {
echo         using var conn = new SqlConnection^(_connectionString^);
echo         await conn.ExecuteAsync^("DELETE FROM ProductsReadModel WHERE Id=@Id", new { Id = id }^);
echo     }
echo.
echo     public async Task^<ProductReadModel?^> GetByIdAsync^(int id, CancellationToken ct = default^)
echo     {
echo         using var conn = new SqlConnection^(_connectionString^);
echo         return await conn.QuerySingleOrDefaultAsync^<ProductReadModel^>^("SELECT * FROM ProductsReadModel WHERE Id=@Id", new { Id = id }^);
echo     }
echo }
    ) > "%projectName%.Infrastructure\Persistence\ReadModels\ProductProjectionWriter.cs"
    )
    if NOT "%useDapper%"=="true" (
        (
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.ReadModels;
echo using System.Linq.Expressions;
echo.
echo namespace %projectName%.Infrastructure.Persistence.Repositories;
echo.
echo public class ReadRepository^<TReadModel^> : IReadRepository^<TReadModel^> where TReadModel : class
echo {
echo     protected readonly ReadDbContext _context;
echo.
echo     public ReadRepository^(ReadDbContext context^) =^> _context = context;
echo.
echo     public async Task^<TReadModel?^> GetByIdAsync^(int id, CancellationToken ct = default^)
echo         =^> await _context.Set^<TReadModel^>^(^).FindAsync^(new object[] { id }, ct^);
echo.
echo     public async Task^<IEnumerable^<TReadModel^>^> GetAllAsync^(CancellationToken ct = default^)
echo         =^> await _context.Set^<TReadModel^>^(^).AsNoTracking^(^).ToListAsync^(ct^);
echo.
echo     public async Task^<IEnumerable^<TReadModel^>^> FindAsync^(Expression^<Func^<TReadModel, bool^>^> predicate, CancellationToken ct = default^)
echo         =^> await _context.Set^<TReadModel^>^(^).Where^(predicate^).AsNoTracking^(^).ToListAsync^(ct^);
echo }
echo.
echo public class ProductReadRepository : ReadRepository^<ProductReadModel^>, IProductReadRepository
echo {
echo     public ProductReadRepository^(ReadDbContext context^) : base^(context^) { }
echo }
echo.
echo public class CustomerReadRepository : ReadRepository^<CustomerReadModel^>, ICustomerReadRepository
echo {
echo     public CustomerReadRepository^(ReadDbContext context^) : base^(context^) { }
echo }
echo.
echo public class OrderReadRepository : ReadRepository^<OrderReadModel^>, IOrderReadRepository
echo {
echo     public OrderReadRepository^(ReadDbContext context^) : base^(context^) { }
echo }
    ) > "%projectName%.Infrastructure\Persistence\Repositories\ReadRepositories.cs"
    )
)
REM ========== PROJECTION WRITERS FALTANTES ==========

if NOT "%cqrsMode%"=="Light" (
    if "%useDapper%"=="true" (
        REM Customer Projection Writer
        (
echo using Dapper;
echo using Microsoft.Data.SqlClient;
echo using Microsoft.Extensions.Configuration;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.ReadModels;
echo.
echo namespace %projectName%.Infrastructure.Persistence.ReadModels;
echo.
echo public class CustomerProjectionWriter : IProjectionWriter^<CustomerReadModel^>
echo {
echo     private readonly string _connectionString;
echo.
echo     public CustomerProjectionWriter^(IConfiguration configuration^)
echo         =^> _connectionString = configuration.GetConnectionString^("ReadConnection"^)!;
echo.
echo     public async Task InsertAsync^(CustomerReadModel model, CancellationToken ct = default^)
echo     {
echo         const string sql = @"INSERT INTO CustomersReadModel ^(Id, FirstName, LastName, FullName, Email, IsActive, CreatedAt^) VALUES ^(@Id, @FirstName, @LastName, @FullName, @Email, @IsActive, @CreatedAt^)";
echo         using var conn = new SqlConnection^(_connectionString^);
echo         await conn.ExecuteAsync^(sql, model^);
echo     }
echo.
echo     public async Task UpdateAsync^(CustomerReadModel model, CancellationToken ct = default^)
echo     {
echo         const string sql = @"UPDATE CustomersReadModel SET FirstName=@FirstName, LastName=@LastName, FullName=@FullName, Email=@Email, IsActive=@IsActive WHERE Id=@Id";
echo         using var conn = new SqlConnection^(_connectionString^);
echo         await conn.ExecuteAsync^(sql, model^);
echo     }
echo.
echo     public async Task DeleteAsync^(int id, CancellationToken ct = default^)
echo     {
echo         using var conn = new SqlConnection^(_connectionString^);
echo         await conn.ExecuteAsync^("DELETE FROM CustomersReadModel WHERE Id=@Id", new { Id = id }^);
echo     }
echo.
echo     public async Task^<CustomerReadModel?^> GetByIdAsync^(int id, CancellationToken ct = default^)
echo     {
echo         using var conn = new SqlConnection^(_connectionString^);
echo         return await conn.QuerySingleOrDefaultAsync^<CustomerReadModel^>^("SELECT * FROM CustomersReadModel WHERE Id=@Id", new { Id = id }^);
echo     }
echo }
    ) > "%projectName%.Infrastructure\Persistence\ReadModels\CustomerProjectionWriter.cs"
        
        REM Order Projection Writer
        (
echo using Dapper;
echo using Microsoft.Data.SqlClient;
echo using Microsoft.Extensions.Configuration;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.ReadModels;
echo.
echo namespace %projectName%.Infrastructure.Persistence.ReadModels;
echo.
echo public class OrderProjectionWriter : IProjectionWriter^<OrderReadModel^>
echo {
echo     private readonly string _connectionString;
echo.
echo     public OrderProjectionWriter^(IConfiguration configuration^)
echo         =^> _connectionString = configuration.GetConnectionString^("ReadConnection"^)!;
echo.
echo     public async Task InsertAsync^(OrderReadModel model, CancellationToken ct = default^)
echo     {
echo         const string sql = @"INSERT INTO OrdersReadModel ^(Id, CustomerId, CustomerName, OrderDate, Status, Total, Currency, ItemCount^) VALUES ^(@Id, @CustomerId, @CustomerName, @OrderDate, @Status, @Total, @Currency, @ItemCount^)";
echo         using var conn = new SqlConnection^(_connectionString^);
echo         await conn.ExecuteAsync^(sql, model^);
echo     }
echo.
echo     public async Task UpdateAsync^(OrderReadModel model, CancellationToken ct = default^)
echo     {
echo         const string sql = @"UPDATE OrdersReadModel SET CustomerId=@CustomerId, CustomerName=@CustomerName, OrderDate=@OrderDate, Status=@Status, Total=@Total, Currency=@Currency, ItemCount=@ItemCount WHERE Id=@Id";
echo         using var conn = new SqlConnection^(_connectionString^);
echo         await conn.ExecuteAsync^(sql, model^);
echo     }
echo.
echo     public async Task DeleteAsync^(int id, CancellationToken ct = default^)
echo     {
echo         using var conn = new SqlConnection^(_connectionString^);
echo         await conn.ExecuteAsync^("DELETE FROM OrdersReadModel WHERE Id=@Id", new { Id = id }^);
echo     }
echo.
echo     public async Task^<OrderReadModel?^> GetByIdAsync^(int id, CancellationToken ct = default^)
echo     {
echo         using var conn = new SqlConnection^(_connectionString^);
echo         return await conn.QuerySingleOrDefaultAsync^<OrderReadModel^>^("SELECT * FROM OrdersReadModel WHERE Id=@Id", new { Id = id }^);
echo     }
echo }
    ) > "%projectName%.Infrastructure\Persistence\ReadModels\OrderProjectionWriter.cs"
    )
    if NOT "%useDapper%"=="true" (
        REM EF Projection Writers
        (
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.ReadModels;
echo.
echo namespace %projectName%.Infrastructure.Persistence.ReadModels;
echo.
echo public class ProductProjectionWriter : IProjectionWriter^<ProductReadModel^>
echo {
echo     private readonly ReadDbContext _context;
echo.
echo     public ProductProjectionWriter^(ReadDbContext context^) =^> _context = context;
echo.
echo     public async Task InsertAsync^(ProductReadModel model, CancellationToken ct = default^)
echo     {
echo         await _context.Set^<ProductReadModel^>^(^).AddAsync^(model, ct^);
echo         await _context.SaveChangesAsync^(ct^);
echo     }
echo.
echo     public async Task UpdateAsync^(ProductReadModel model, CancellationToken ct = default^)
echo     {
echo         _context.Set^<ProductReadModel^>^(^).Update^(model^);
echo         await _context.SaveChangesAsync^(ct^);
echo     }
echo.
echo     public async Task DeleteAsync^(int id, CancellationToken ct = default^)
echo     {
echo         var model = await GetByIdAsync^(id, ct^);
echo         if ^(model != null^)
echo         {
echo             _context.Set^<ProductReadModel^>^(^).Remove^(model^);
echo             await _context.SaveChangesAsync^(ct^);
echo         }
echo     }
echo.
echo     public async Task^<ProductReadModel?^> GetByIdAsync^(int id, CancellationToken ct = default^)
echo         =^> await _context.Set^<ProductReadModel^>^(^).FindAsync^(new object[] { id }, ct^);
echo }
echo.
echo public class CustomerProjectionWriter : IProjectionWriter^<CustomerReadModel^>
echo {
echo     private readonly ReadDbContext _context;
echo.
echo     public CustomerProjectionWriter^(ReadDbContext context^) =^> _context = context;
echo.
echo     public async Task InsertAsync^(CustomerReadModel model, CancellationToken ct = default^)
echo     {
echo         await _context.Set^<CustomerReadModel^>^(^).AddAsync^(model, ct^);
echo         await _context.SaveChangesAsync^(ct^);
echo     }
echo.
echo     public async Task UpdateAsync^(CustomerReadModel model, CancellationToken ct = default^)
echo     {
echo         _context.Set^<CustomerReadModel^>^(^).Update^(model^);
echo         await _context.SaveChangesAsync^(ct^);
echo     }
echo.
echo     public async Task DeleteAsync^(int id, CancellationToken ct = default^)
echo     {
echo         var model = await GetByIdAsync^(id, ct^);
echo         if ^(model != null^)
echo         {
echo             _context.Set^<CustomerReadModel^>^(^).Remove^(model^);
echo             await _context.SaveChangesAsync^(ct^);
echo         }
echo     }
echo.
echo     public async Task^<CustomerReadModel?^> GetByIdAsync^(int id, CancellationToken ct = default^)
echo         =^> await _context.Set^<CustomerReadModel^>^(^).FindAsync^(new object[] { id }, ct^);
echo }
echo.
echo public class OrderProjectionWriter : IProjectionWriter^<OrderReadModel^>
echo {
echo     private readonly ReadDbContext _context;
echo.
echo     public OrderProjectionWriter^(ReadDbContext context^) =^> _context = context;
echo.
echo     public async Task InsertAsync^(OrderReadModel model, CancellationToken ct = default^)
echo     {
echo         await _context.Set^<OrderReadModel^>^(^).AddAsync^(model, ct^);
echo         await _context.SaveChangesAsync^(ct^);
echo     }
echo.
echo     public async Task UpdateAsync^(OrderReadModel model, CancellationToken ct = default^)
echo     {
echo         _context.Set^<OrderReadModel^>^(^).Update^(model^);
echo         await _context.SaveChangesAsync^(ct^);
echo     }
echo.
echo     public async Task DeleteAsync^(int id, CancellationToken ct = default^)
echo     {
echo         var model = await GetByIdAsync^(id, ct^);
echo         if ^(model != null^)
echo         {
echo             _context.Set^<OrderReadModel^>^(^).Remove^(model^);
echo             await _context.SaveChangesAsync^(ct^);
echo         }
echo     }
echo.
echo     public async Task^<OrderReadModel?^> GetByIdAsync^(int id, CancellationToken ct = default^)
echo         =^> await _context.Set^<OrderReadModel^>^(^).FindAsync^(new object[] { id }, ct^);
echo }
    ) > "%projectName%.Infrastructure\Persistence\ReadModels\ProjectionWriters.cs"
    )
    
    REM PROYECCIONES CUSTOMER Y ORDER
    (
echo using MediatR;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.ReadModels;
echo using %projectName%.Domain.Events;
echo.
echo namespace %projectName%.Application.Projections;
echo.
echo public class CustomerCreatedProjection : INotificationHandler^<CustomerCreatedEvent^>
echo {
echo     private readonly IProjectionWriter^<CustomerReadModel^> _writer;
echo.
echo     public CustomerCreatedProjection^(IProjectionWriter^<CustomerReadModel^> writer^) =^> _writer = writer;
echo.
echo     public async Task Handle^(CustomerCreatedEvent evt, CancellationToken ct^)
echo     {
echo         var model = new CustomerReadModel
echo         {
echo             Id = evt.Customer.Id.Value,
echo             FirstName = evt.Customer.FirstName,
echo             LastName = evt.Customer.LastName,
echo             FullName = evt.Customer.GetFullName^(^),
echo             Email = evt.Customer.Email.Address,
echo             IsActive = evt.Customer.IsActive,
echo             CreatedAt = evt.Customer.CreatedAt
echo         };
echo.
echo         await _writer.InsertAsync^(model, ct^);
echo     }
echo }
echo.
echo public class OrderCreatedProjection : INotificationHandler^<OrderCreatedEvent^>
echo {
echo     private readonly IProjectionWriter^<OrderReadModel^> _writer;
echo.
echo     public OrderCreatedProjection^(IProjectionWriter^<OrderReadModel^> writer^) =^> _writer = writer;
echo.
echo     public async Task Handle^(OrderCreatedEvent evt, CancellationToken ct^)
echo     {
echo         var model = new OrderReadModel
echo         {
echo             Id = evt.Order.Id.Value,
echo             CustomerId = evt.Order.CustomerId.Value,
echo             CustomerName = string.Empty,
echo             OrderDate = evt.Order.OrderDate,
echo             Status = evt.Order.Status.ToString^(^),
echo             Total = evt.Order.GetTotal^(^).Amount,
echo             Currency = evt.Order.GetTotal^(^).Currency,
echo             ItemCount = evt.Order.Items.Count
echo         };
echo.
echo         await _writer.InsertAsync^(model, ct^);
echo     }
echo }
echo.
echo public class OrderConfirmedProjection : INotificationHandler^<OrderConfirmedEvent^>
echo {
echo     private readonly IProjectionWriter^<OrderReadModel^> _writer;
echo.
echo     public OrderConfirmedProjection^(IProjectionWriter^<OrderReadModel^> writer^) =^> _writer = writer;
echo.
echo     public async Task Handle^(OrderConfirmedEvent evt, CancellationToken ct^)
echo     {
echo         var model = await _writer.GetByIdAsync^(evt.Order.Id.Value, ct^);
echo         if ^(model != null^)
echo         {
echo             model.Status = evt.Order.Status.ToString^(^);
echo             model.Total = evt.Order.GetTotal^(^).Amount;
echo             model.Currency = evt.Order.GetTotal^(^).Currency;
echo             model.ItemCount = evt.Order.Items.Count;
echo             await _writer.UpdateAsync^(model, ct^);
echo         }
echo     }
echo }
    ) > "%projectName%.Application\Projections\CustomerOrderProjections.cs"
)

REM ========== UNIT OF WORK IMPLEMENTATION ==========

if "%cqrsMode%"=="Light" (
    (
echo using Microsoft.EntityFrameworkCore.Storage;
echo using %projectName%.Application.Common.Interfaces;
echo.
echo namespace %projectName%.Infrastructure.Persistence;
echo.
echo public class UnitOfWork : IUnitOfWork
echo {
echo     private readonly ApplicationDbContext _context;
echo     private IDbContextTransaction? _transaction;
echo.
echo     public UnitOfWork^(ApplicationDbContext context^) =^> _context = context;
echo.
echo     public async Task^<int^> SaveChangesAsync^(CancellationToken ct = default^)
echo         =^> await _context.SaveChangesAsync^(ct^);
echo.
echo     public async Task BeginTransactionAsync^(CancellationToken ct = default^)
echo         =^> _transaction = await _context.Database.BeginTransactionAsync^(ct^);
echo.
echo     public async Task CommitTransactionAsync^(CancellationToken ct = default^)
echo     {
echo         if ^(_transaction != null^)
echo         {
echo             await _transaction.CommitAsync^(ct^);
echo             await _transaction.DisposeAsync^(^);
echo             _transaction = null;
echo         }
echo     }
echo.
echo     public async Task RollbackTransactionAsync^(CancellationToken ct = default^)
echo     {
echo         if ^(_transaction != null^)
echo         {
echo             await _transaction.RollbackAsync^(ct^);
echo             await _transaction.DisposeAsync^(^);
echo             _transaction = null;
echo         }
echo     }
echo }
    ) > "%projectName%.Infrastructure\Persistence\UnitOfWork.cs"
) else (
    (
echo using Microsoft.EntityFrameworkCore.Storage;
echo using %projectName%.Application.Common.Interfaces;
echo.
echo namespace %projectName%.Infrastructure.Persistence;
echo.
echo public class UnitOfWork : IUnitOfWork
echo {
echo     private readonly WriteDbContext _context;
echo     private IDbContextTransaction? _transaction;
echo.
echo     public UnitOfWork^(WriteDbContext context^) =^> _context = context;
echo.
echo     public async Task^<int^> SaveChangesAsync^(CancellationToken ct = default^)
echo         =^> await _context.SaveChangesAsync^(ct^);
echo.
echo     public async Task BeginTransactionAsync^(CancellationToken ct = default^)
echo         =^> _transaction = await _context.Database.BeginTransactionAsync^(ct^);
echo.
echo     public async Task CommitTransactionAsync^(CancellationToken ct = default^)
echo     {
echo         if ^(_transaction != null^)
echo         {
echo             await _transaction.CommitAsync^(ct^);
echo             await _transaction.DisposeAsync^(^);
echo             _transaction = null;
echo         }
echo     }
echo.
echo     public async Task RollbackTransactionAsync^(CancellationToken ct = default^)
echo     {
echo         if ^(_transaction != null^)
echo         {
echo             await _transaction.RollbackAsync^(ct^);
echo             await _transaction.DisposeAsync^(^);
echo             _transaction = null;
echo         }
echo     }
echo }
    ) > "%projectName%.Infrastructure\Persistence\UnitOfWork.cs"
)

REM ========== EVENT STORE IMPLEMENTATION ==========

(
echo using Microsoft.EntityFrameworkCore;
echo using Newtonsoft.Json;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Domain.Common;
echo.
echo namespace %projectName%.Infrastructure.EventSourcing;
echo.
echo public class EventStore : IEventStore
echo {
echo     private readonly EventStoreDbContext _context;
echo.
echo     public EventStore^(EventStoreDbContext context^) =^> _context = context;
echo.
echo     public async Task SaveEventAsync^(IDomainEvent domainEvent, string aggregateType, int aggregateId, CancellationToken ct = default^)
echo     {
echo         var storedEvent = new StoredEvent
echo         {
echo             EventId = domainEvent.EventId,
echo             AggregateType = aggregateType,
echo             AggregateId = aggregateId,
echo             EventType = domainEvent.GetType^(^).Name,
echo             EventData = JsonConvert.SerializeObject^(domainEvent^),
echo             OccurredOn = domainEvent.OccurredOn,
echo             Version = 1
echo         };
echo.
echo         await _context.Events.AddAsync^(storedEvent, ct^);
echo         await _context.SaveChangesAsync^(ct^);
echo     }
echo.
echo     public async Task^<IEnumerable^<StoredEvent^>^> GetEventsAsync^(string aggregateType, int aggregateId, CancellationToken ct = default^)
echo         =^> await _context.Events
echo             .Where^(e =^> e.AggregateType == aggregateType ^&^& e.AggregateId == aggregateId^)
echo             .OrderBy^(e =^> e.Version^)
echo             .ToListAsync^(ct^);
echo.
echo     public async Task^<IEnumerable^<StoredEvent^>^> GetAllEventsAsync^(CancellationToken ct = default^)
echo         =^> await _context.Events.OrderBy^(e =^> e.OccurredOn^).ToListAsync^(ct^);
echo }
) > "%projectName%.Infrastructure\EventSourcing\EventStore.cs"

(
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Application.Common.Interfaces;
echo.
echo namespace %projectName%.Infrastructure.EventSourcing;
echo.
echo public class EventStoreDbContext : DbContext
echo {
echo     public DbSet^<StoredEvent^> Events { get; set; } = null!;
echo.
echo     public EventStoreDbContext^(DbContextOptions^<EventStoreDbContext^> options^) : base^(options^) { }
echo.
echo     protected override void OnModelCreating^(ModelBuilder modelBuilder^)
echo     {
echo         modelBuilder.Entity^<StoredEvent^>^(e =^>
echo         {
echo             e.ToTable^("DomainEvents"^);
echo             e.HasKey^(x =^> x.Id^);
echo             e.Property^(x =^> x.Id^).ValueGeneratedOnAdd^(^);
echo             e.HasIndex^(x =^> new { x.AggregateType, x.AggregateId }^);
echo             e.HasIndex^(x =^> x.OccurredOn^);
echo         }^);
echo     }
echo }
) > "%projectName%.Infrastructure\EventSourcing\EventStoreDbContext.cs"

REM ========== DOMAIN EVENT DISPATCHER ==========

(
echo using MediatR;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Domain.Common;
echo.
echo namespace %projectName%.Infrastructure.Services;
echo.
echo public class DomainEventDispatcher : IDomainEventDispatcher
echo {
echo     private readonly IMediator _mediator;
echo     private readonly IEventStore _eventStore;
echo.
echo     public DomainEventDispatcher^(IMediator mediator, IEventStore eventStore^)
echo     {
echo         _mediator = mediator;
echo         _eventStore = eventStore;
echo     }
echo.
echo     public async Task DispatchAsync^(IDomainEvent domainEvent, CancellationToken ct = default^)
echo     {
echo         await _mediator.Publish^(domainEvent, ct^);
echo     }
echo.
echo     public async Task DispatchAsync^(IEnumerable^<IDomainEvent^> domainEvents, CancellationToken ct = default^)
echo     {
echo         foreach ^(var domainEvent in domainEvents^)
echo         {
echo             await _mediator.Publish^(domainEvent, ct^);
echo         }
echo     }
echo }
) > "%projectName%.Infrastructure\Services\DomainEventDispatcher.cs"

REM ========== DEPENDENCY INJECTION INFRASTRUCTURE ==========

if "%cqrsMode%"=="Light" (
    (
echo using Microsoft.EntityFrameworkCore;
echo using Microsoft.Extensions.Configuration;
echo using Microsoft.Extensions.DependencyInjection;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Infrastructure.EventSourcing;
echo using %projectName%.Infrastructure.Persistence;
echo using %projectName%.Infrastructure.Persistence.Repositories;
echo using %projectName%.Infrastructure.Services;
echo.
echo namespace %projectName%.Infrastructure;
echo.
echo public static class DependencyInjection
echo {
echo     public static IServiceCollection AddInfrastructure^(this IServiceCollection services, IConfiguration configuration^)
echo     {
echo         services.AddDbContext^<ApplicationDbContext^>^(options =^>
echo             options.UseSqlServer^(configuration.GetConnectionString^("DefaultConnection"^)^)^);
echo.
echo         services.AddDbContext^<EventStoreDbContext^>^(options =^>
echo             options.UseSqlServer^(configuration.GetConnectionString^("EventStoreConnection"^)^)^);
echo.
echo         services.AddScoped^<IUnitOfWork, UnitOfWork^>^(^);
echo         services.AddScoped^<IEventStore, EventStore^>^(^);
echo         services.AddScoped^<IDomainEventDispatcher, DomainEventDispatcher^>^(^);
echo.
echo         services.AddScoped^<IProductRepository, ProductRepository^>^(^);
echo         services.AddScoped^<ICustomerRepository, CustomerRepository^>^(^);
echo         services.AddScoped^<IOrderRepository, OrderRepository^>^(^);
echo.
echo         return services;
echo     }
echo }
    ) > "%projectName%.Infrastructure\DependencyInjection.cs"
) else if "%useDapper%"=="true" (
    (
echo using Microsoft.EntityFrameworkCore;
echo using Microsoft.Extensions.Configuration;
echo using Microsoft.Extensions.DependencyInjection;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.ReadModels;
echo using %projectName%.Infrastructure.EventSourcing;
echo using %projectName%.Infrastructure.Persistence;
echo using %projectName%.Infrastructure.Persistence.Queries;
echo using %projectName%.Infrastructure.Persistence.ReadModels;
echo using %projectName%.Infrastructure.Persistence.Repositories;
echo using %projectName%.Infrastructure.Services;
echo.
echo namespace %projectName%.Infrastructure;
echo.
echo public static class DependencyInjection
echo {
echo     public static IServiceCollection AddInfrastructure^(this IServiceCollection services, IConfiguration configuration^)
echo     {
echo         services.AddDbContext^<WriteDbContext^>^(options =^>
echo             options.UseSqlServer^(configuration.GetConnectionString^("WriteConnection"^)^)^);
echo.
echo         services.AddDbContext^<EventStoreDbContext^>^(options =^>
echo             options.UseSqlServer^(configuration.GetConnectionString^("EventStoreConnection"^)^)^);
echo.
echo         services.AddScoped^<IUnitOfWork, UnitOfWork^>^(^);
echo         services.AddScoped^<IEventStore, EventStore^>^(^);
echo         services.AddScoped^<IDomainEventDispatcher, DomainEventDispatcher^>^(^);
echo.
echo         services.AddScoped^<IProductWriteRepository, ProductWriteRepository^>^(^);
echo         services.AddScoped^<ICustomerWriteRepository, CustomerWriteRepository^>^(^);
echo         services.AddScoped^<IOrderWriteRepository, OrderWriteRepository^>^(^);
echo.
echo         services.AddScoped^<IQueryService, DapperQueryService^>^(^);
echo.
echo         services.AddScoped^<IProjectionWriter^<ProductReadModel^>, ProductProjectionWriter^>^(^);
echo         services.AddScoped^<IProjectionWriter^<CustomerReadModel^>, CustomerProjectionWriter^>^(^);
echo         services.AddScoped^<IProjectionWriter^<OrderReadModel^>, OrderProjectionWriter^>^(^);
echo.
echo         return services;
echo     }
echo }
    ) > "%projectName%.Infrastructure\DependencyInjection.cs"
) else (
    (
echo using Microsoft.EntityFrameworkCore;
echo using Microsoft.Extensions.Configuration;
echo using Microsoft.Extensions.DependencyInjection;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.ReadModels;
echo using %projectName%.Infrastructure.EventSourcing;
echo using %projectName%.Infrastructure.Persistence;
echo using %projectName%.Infrastructure.Persistence.ReadModels;
echo using %projectName%.Infrastructure.Persistence.Repositories;
echo using %projectName%.Infrastructure.Services;
echo.
echo namespace %projectName%.Infrastructure;
echo.
echo public static class DependencyInjection
echo {
echo     public static IServiceCollection AddInfrastructure^(this IServiceCollection services, IConfiguration configuration^)
echo     {
echo         services.AddDbContext^<WriteDbContext^>^(options =^>
echo             options.UseSqlServer^(configuration.GetConnectionString^("WriteConnection"^)^)^);
echo.
echo         services.AddDbContext^<ReadDbContext^>^(options =^>
echo             options.UseSqlServer^(configuration.GetConnectionString^("ReadConnection"^)^)^);
echo.
echo         services.AddDbContext^<EventStoreDbContext^>^(options =^>
echo             options.UseSqlServer^(configuration.GetConnectionString^("EventStoreConnection"^)^)^);
echo.
echo         services.AddScoped^<IUnitOfWork, UnitOfWork^>^(^);
echo         services.AddScoped^<IEventStore, EventStore^>^(^);
echo         services.AddScoped^<IDomainEventDispatcher, DomainEventDispatcher^>^(^);
echo.
echo         services.AddScoped^<IProductWriteRepository, ProductWriteRepository^>^(^);
echo         services.AddScoped^<ICustomerWriteRepository, CustomerWriteRepository^>^(^);
echo         services.AddScoped^<IOrderWriteRepository, OrderWriteRepository^>^(^);
echo.
echo         services.AddScoped^<IProductReadRepository, ProductReadRepository^>^(^);
echo         services.AddScoped^<ICustomerReadRepository, CustomerReadRepository^>^(^);
echo         services.AddScoped^<IOrderReadRepository, OrderReadRepository^>^(^);
echo.
echo         services.AddScoped^<IProjectionWriter^<ProductReadModel^>, ProductProjectionWriter^>^(^);
echo         services.AddScoped^<IProjectionWriter^<CustomerReadModel^>, CustomerProjectionWriter^>^(^);
echo         services.AddScoped^<IProjectionWriter^<OrderReadModel^>, OrderProjectionWriter^>^(^);
echo.
echo         return services;
echo     }
echo }
    ) > "%projectName%.Infrastructure\DependencyInjection.cs"
)

REM ========== CONTROLLERS ==========

if "%uiProject%"=="API" (
    mkdir "%projectName%.API\Controllers"
    (
echo using MediatR;
echo using Microsoft.AspNetCore.Mvc;
echo using %projectName%.Application.Commands.Products;
echo using %projectName%.Application.Queries.Products;
echo.
echo namespace %projectName%.API.Controllers;
echo.
echo [ApiController]
echo [Route^("api/[controller]"^)]
echo public class ProductsController : ControllerBase
echo {
echo     private readonly IMediator _mediator;
echo.
echo     public ProductsController^(IMediator mediator^) =^> _mediator = mediator;
echo.
echo     [HttpGet]
echo     public async Task^<IActionResult^> GetAll^(CancellationToken ct^)
echo     {
echo         var result = await _mediator.Send^(new GetProductsQuery^(^), ct^);
echo         return Ok^(result^);
echo     }
echo.
echo     [HttpGet^("{id}"^)]
echo     public async Task^<IActionResult^> GetById^(int id, CancellationToken ct^)
echo     {
echo         var result = await _mediator.Send^(new GetProductByIdQuery^(id^), ct^);
echo         return result == null ? NotFound^(^) : Ok^(result^);
echo     }
echo.
echo     [HttpGet^("active"^)]
echo     public async Task^<IActionResult^> GetActive^(CancellationToken ct^)
echo     {
echo         var result = await _mediator.Send^(new GetActiveProductsQuery^(^), ct^);
echo         return Ok^(result^);
echo     }
echo.
echo     [HttpGet^("in-stock"^)]
echo     public async Task^<IActionResult^> GetInStock^(CancellationToken ct^)
echo     {
echo         var result = await _mediator.Send^(new GetProductsInStockQuery^(^), ct^);
echo         return Ok^(result^);
echo     }
echo.
echo     [HttpGet^("price-range"^)]
echo     public async Task^<IActionResult^> GetByPriceRange^([FromQuery] decimal minPrice, [FromQuery] decimal maxPrice, CancellationToken ct^)
echo     {
echo         var result = await _mediator.Send^(new GetProductsByPriceRangeQuery^(minPrice, maxPrice^), ct^);
echo         return Ok^(result^);
echo     }
echo.
echo     [HttpPost]
echo     public async Task^<IActionResult^> Create^([FromBody] CreateProductCommand command, CancellationToken ct^)
echo     {
echo         var productId = await _mediator.Send^(command, ct^);
echo         return CreatedAtAction^(nameof^(GetById^), new { id = productId.Value }, productId^);
echo     }
echo.
echo     [HttpPut^("{id}/price"^)]
echo     public async Task^<IActionResult^> UpdatePrice^(int id, [FromBody] UpdateProductPriceCommand command, CancellationToken ct^)
echo     {
echo         if ^(id != command.ProductId^) return BadRequest^(^);
echo         var result = await _mediator.Send^(command, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo.
echo     [HttpPost^("{id}/stock/add"^)]
echo     public async Task^<IActionResult^> AddStock^(int id, [FromBody] AddStockCommand command, CancellationToken ct^)
echo     {
echo         if ^(id != command.ProductId^) return BadRequest^(^);
echo         var result = await _mediator.Send^(command, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo.
echo     [HttpPost^("{id}/stock/remove"^)]
echo     public async Task^<IActionResult^> RemoveStock^(int id, [FromBody] RemoveStockCommand command, CancellationToken ct^)
echo     {
echo         if ^(id != command.ProductId^) return BadRequest^(^);
echo         var result = await _mediator.Send^(command, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo.
echo     [HttpPost^("{id}/deactivate"^)]
echo     public async Task^<IActionResult^> Deactivate^(int id, CancellationToken ct^)
echo     {
echo         var result = await _mediator.Send^(new DeactivateProductCommand { ProductId = id }, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo }
) > "%projectName%.API\Controllers\ProductsController.cs"
)
REM ========== MIDDLEWARE DE EXCEPCIONES (API) ==========

mkdir "%projectName%.%uiProject%\Middleware"
(
echo using System.Net;
echo using System.Text.Json;
echo using %projectName%.Domain.Exceptions;
echo.
echo namespace %projectName%.%uiProject%.Middleware;
echo.
echo public class ExceptionMiddleware
echo {
echo     private readonly RequestDelegate _next;
echo     private readonly ILogger^<ExceptionMiddleware^> _logger;
echo.
echo     public ExceptionMiddleware^(RequestDelegate next, ILogger^<ExceptionMiddleware^> logger^)
echo     {
echo         _next = next;
echo         _logger = logger;
echo     }
echo.
echo     public async Task InvokeAsync^(HttpContext context^)
echo     {
echo         try { await _next^(context^); }
echo         catch ^(Exception ex^) { await HandleExceptionAsync^(context, ex^); }
echo     }
echo.
echo     private Task HandleExceptionAsync^(HttpContext context, Exception exception^)
echo     {
echo         context.Response.ContentType = "application/json";
echo         var statusCode = exception switch
echo         {
echo             DomainException =^> ^(int^)HttpStatusCode.BadRequest,
echo             _ =^> ^(int^)HttpStatusCode.InternalServerError
echo         };
echo.
echo         context.Response.StatusCode = statusCode;
echo         var response = new { error = exception.Message, details = exception.InnerException?.Message };
echo         return context.Response.WriteAsync^(JsonSerializer.Serialize^(response^)^);
echo     }
echo }
) > "%projectName%.%uiProject%\Middleware\ExceptionMiddleware.cs"

REM ========== LOGGING BEHAVIOR (APPLICATION) ==========

(
echo using MediatR;
echo using Microsoft.Extensions.Logging;
echo using System.Diagnostics;
echo.
echo namespace %projectName%.Application.Common.Behaviors;
echo.
echo public class LoggingBehavior^<TRequest, TResponse^> : IPipelineBehavior^<TRequest, TResponse^>
echo     where TRequest : IRequest^<TResponse^>
echo {
echo     private readonly ILogger^<LoggingBehavior^<TRequest, TResponse^>^> _logger;
echo.
echo     public LoggingBehavior^(ILogger^<LoggingBehavior^<TRequest, TResponse^>^> logger^) =^> _logger = logger;
echo.
echo     public async Task^<TResponse^> Handle^(TRequest request, RequestHandlerDelegate^<TResponse^> next, CancellationToken ct^)
echo     {
echo         var timer = Stopwatch.StartNew^(^);
echo         _logger.LogInformation^("Ejecutando comando: {Name}", typeof^(TRequest^).Name^);
echo.
echo         var response = await next^(^);
echo.
echo         timer.Stop^(^);
echo         _logger.LogInformation^("Finalizado: {Name} en {Elapsed}ms", typeof^(TRequest^).Name, timer.ElapsedMilliseconds^);
echo         return response;
echo     }
echo }
) > "%projectName%.Application\Common\Behaviors\LoggingBehavior.cs"

REM ========== DOCKER CONFIGURATION ==========

set projectNameLower=%projectName%
call :LCase projectNameLower

(
echo version: '3.4'
echo.
echo services:
echo   sqlserver:
echo     image: mcr.microsoft.com/mssql/server:2022-latest
echo     ports:
echo       - "1433:1433"
echo     environment:
echo       - ACCEPT_EULA=Y
echo       - MSSQL_SA_PASSWORD=YourStrong@Password
echo.
echo   %projectNameLower%:
echo     image: ${DOCKER_REGISTRY-}%projectNameLower%
echo     build:
echo       context: .
echo       dockerfile: src/%projectName%.%uiProject%/Dockerfile
echo     depends_on:
echo       - sqlserver
) > "%projectDirectory%\docker-compose.yml"

goto :AfterLCase

:LCase
for %%L IN (a b c d e f g h i j k l m n o p q r s t u v w x y z) DO call set %1=%%%1:%%L=%%L%%
goto :eof

:AfterLCase

REM Program.cs configuration
(
echo using %projectName%.Application;
echo using %projectName%.Infrastructure;
echo using %projectName%.%uiProject%.Middleware;
echo.
echo var builder = WebApplication.CreateBuilder^(args^);
echo.
echo builder.Services.AddControllers^(^);
echo builder.Services.AddEndpointsApiExplorer^(^);
echo builder.Services.AddSwaggerGen^(^);
echo.
echo builder.Services.AddApplication^(^);
echo builder.Services.AddInfrastructure^(builder.Configuration^);
echo.
echo var app = builder.Build^(^);
echo.
echo if ^(app.Environment.IsDevelopment^(^)^)
echo {
echo     app.UseSwagger^(^);
echo     app.UseSwaggerUI^(^);
echo }
echo.
echo app.UseHttpsRedirection^(^);
echo app.UseMiddleware^<ExceptionMiddleware^>^(^);
echo app.UseAuthorization^(^);
echo app.MapControllers^(^);
echo.
echo app.Run^(^);
) > "%projectName%.API\Program.cs"

REM appsettings.json
if "%cqrsMode%"=="Light" (
    (
echo {
echo   "ConnectionStrings": {
echo     "DefaultConnection": "Server=localhost;Database=%projectName%Db;Trusted_Connection=True;TrustServerCertificate=True",
echo     "EventStoreConnection": "Server=localhost;Database=%projectName%EventStore;Trusted_Connection=True;TrustServerCertificate=True"
echo   },
echo   "Logging": {
echo     "LogLevel": {
echo       "Default": "Information",
echo       "Microsoft.AspNetCore": "Warning"
echo     }
echo   },
echo   "AllowedHosts": "*"
echo }
) > "%projectName%.API\appsettings.json"
) else (
(
echo {
echo   "ConnectionStrings": {
echo     "WriteConnection": "Server=localhost;Database=%projectName%WriteDb;Trusted_Connection=True;TrustServerCertificate=True",
echo     "ReadConnection": "Server=localhost;Database=%projectName%ReadDb;Trusted_Connection=True;TrustServerCertificate=True",
echo     "EventStoreConnection": "Server=localhost;Database=%projectName%EventStore;Trusted_Connection=True;TrustServerCertificate=True"
echo   },
echo   "Logging": {
echo     "LogLevel": {
echo       "Default": "Information",
echo       "Microsoft.AspNetCore": "Warning"
echo     }
echo   },
echo   "AllowedHosts": "*"
echo }
) > "%projectName%.API\appsettings.json"
)

REM ========== ACTUALIZANDO DEPENDENCYINJECTION.CS DE APPLICATION ==========

echo.
echo [INFO] Registrando LoggingBehavior en DependencyInjection.cs...

(
echo using System.Reflection;
echo using FluentValidation;
echo using MediatR;
echo using Microsoft.Extensions.DependencyInjection;
echo using %projectName%.Application.Common.Behaviors;
echo.
echo namespace %projectName%.Application;
echo.
echo public static class DependencyInjection
echo {
echo     public static IServiceCollection AddApplication^(this IServiceCollection services^)
echo     {
echo         var assembly = Assembly.GetExecutingAssembly^(^);
echo.
echo         services.AddMediatR^(cfg =^> cfg.RegisterServicesFromAssembly^(assembly^)^);
echo         services.AddValidatorsFromAssembly^(assembly^);
echo         services.AddAutoMapper^(assembly^);
echo.
echo         services.AddTransient^(typeof^(IPipelineBehavior^<,^>^), typeof^(ValidationBehavior^<,^>^)^);
echo         services.AddTransient^(typeof^(IPipelineBehavior^<,^>^), typeof^(LoggingBehavior^<,^>^)^);
echo.
echo         return services;
echo     }
echo }
) > "%projectName%.Application\DependencyInjection.cs"

echo.
echo ============================================================
echo === AGREGANDO REFERENCIAS ENTRE PROYECTOS ===
echo ============================================================

REM --- Application - Domain ---

cd "%projectName%.Application"
if errorlevel 1 exit /b
dotnet add reference "..\%projectName%.Domain\%projectName%.Domain.csproj"
cd ..

REM --- Infrastructure - Domain & Application ---
cd "%projectName%.Infrastructure"
if errorlevel 1 exit /b
dotnet add reference "..\%projectName%.Domain\%projectName%.Domain.csproj"
dotnet add reference "..\%projectName%.Application\%projectName%.Application.csproj"
cd ..

REM --- UI - Application & Infrastructure ---
cd "%projectName%.%uiProject%"
if errorlevel 1 exit /b
dotnet add reference "..\%projectName%.Application\%projectName%.Application.csproj"
dotnet add reference "..\%projectName%.Infrastructure\%projectName%.Infrastructure.csproj"
cd ..

echo.
echo ============================================================
echo === CREANDO PROYECTOS DE PRUEBAS (APPLICATION e INFRA) ===
echo ============================================================

cd "%projectDirectory%\tests"

REM --- PROYECTO DE TESTS DE APLICACIÓN ---
dotnet new xunit -o "%projectName%.Application.Tests"
if exist "%projectName%.Application.Tests\UnitTest1.cs" del /f /q "%projectName%.Application.Tests\UnitTest1.cs"
dotnet sln "%projectDirectory%\src\%projectName%.sln" add "%projectName%.Application.Tests"
dotnet add "%projectName%.Application.Tests" reference "%projectDirectory%\src\%projectName%.Application\%projectName%.Application.csproj"
dotnet add "%projectName%.Application.Tests" reference "%projectDirectory%\src\%projectName%.Domain\%projectName%.Domain.csproj"

cd "%projectName%.Application.Tests"
dotnet add package Moq
dotnet add package FluentAssertions
cd ..

REM --- PROYECTO DE TESTS DE INFRAESTRUCTURA ---
dotnet new xunit -o "%projectName%.Infrastructure.Tests"
if exist "%projectName%.Infrastructure.Tests\UnitTest1.cs" del /f /q "%projectName%.Infrastructure.Tests\UnitTest1.cs"
dotnet sln "%projectDirectory%\src\%projectName%.sln" add "%projectName%.Infrastructure.Tests"
dotnet add "%projectName%.Infrastructure.Tests" reference "%projectDirectory%\src\%projectName%.Infrastructure\%projectName%.Infrastructure.csproj"
dotnet add "%projectName%.Infrastructure.Tests" reference "%projectDirectory%\src\%projectName%.Domain\%projectName%.Domain.csproj"

cd "%projectName%.Infrastructure.Tests"
dotnet add package Microsoft.EntityFrameworkCore.InMemory
dotnet add package FluentAssertions
cd ..

REM ============================================================
REM === GENERANDO TESTS DE APPLICATION ===
REM ============================================================

if "%cqrsMode%"=="Light" (

REM --- CreateProductCommandHandlerTests ---
(
echo using Moq;
echo using FluentAssertions;
echo using %projectName%.Application.Commands.Products;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Application.Tests;
echo.
echo public class CreateProductCommandHandlerTests
echo {
echo     private readonly Mock^<IProductRepository^> _productRepoMock;
echo     private readonly Mock^<IUnitOfWork^> _uowMock;
echo     private readonly Mock^<IDomainEventDispatcher^> _dispatcherMock;
echo     private readonly CreateProductCommandHandler _handler;
echo.
echo     public CreateProductCommandHandlerTests^(^)
echo     {
echo         _productRepoMock = new Mock^<IProductRepository^>^(^);
echo         _uowMock = new Mock^<IUnitOfWork^>^(^);
echo         _dispatcherMock = new Mock^<IDomainEventDispatcher^>^(^);
echo         _handler = new CreateProductCommandHandler^(
echo             _productRepoMock.Object,
echo             _uowMock.Object,
echo             _dispatcherMock.Object^);
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldCreateProduct_AndSaveInRepository^(^)
echo     {
echo         // Arrange
echo         var command = new CreateProductCommand
echo         {
echo             Name = "Test Product",
echo             Price = 100,
echo             Currency = "USD",
echo             Description = "Test Desc"
echo         };
echo.
echo         // Act
echo         var result = await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         _productRepoMock.Verify^(r =^> r.AddAsync^(It.IsAny^<Product^>^(^), It.IsAny^<CancellationToken^>^(^)^), Times.Once^);
echo         _uowMock.Verify^(u =^> u.SaveChangesAsync^(It.IsAny^<CancellationToken^>^(^)^), Times.Once^);
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldReturnProductId_WhenProductIsCreated^(^)
echo     {
echo         // Arrange
echo         var command = new CreateProductCommand
echo         {
echo             Name = "My Product",
echo             Price = 250,
echo             Currency = "USD",
echo             Description = "Description"
echo         };
echo.
echo         // Act
echo         var result = await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).BeOfType^<ProductId^>^(^);
echo         result.Value.Should^(^).Be^(0^); // nuevo producto, Id temporal
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldDispatchDomainEvents_AfterSave^(^)
echo     {
echo         // Arrange
echo         var command = new CreateProductCommand
echo         {
echo             Name = "Event Product",
echo             Price = 10,
echo             Currency = "USD",
echo             Description = ""
echo         };
echo.
echo         // Act
echo         await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         _dispatcherMock.Verify^(
echo             d =^> d.DispatchAsync^(It.IsAny^<IEnumerable^<IDomainEvent^>^>^(^), It.IsAny^<CancellationToken^>^(^)^),
echo             Times.Once^);
echo     }
echo }
) > "%projectName%.Application.Tests\CreateProductCommandHandlerTests.cs"

REM --- UpdateProductPriceCommandHandlerTests ---
(
echo using Moq;
echo using FluentAssertions;
echo using %projectName%.Application.Commands.Products;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Application.Tests;
echo.
echo public class UpdateProductPriceCommandHandlerTests
echo {
echo     private readonly Mock^<IProductRepository^> _productRepoMock;
echo     private readonly Mock^<IUnitOfWork^> _uowMock;
echo     private readonly Mock^<IDomainEventDispatcher^> _dispatcherMock;
echo     private readonly UpdateProductPriceCommandHandler _handler;
echo.
echo     public UpdateProductPriceCommandHandlerTests^(^)
echo     {
echo         _productRepoMock = new Mock^<IProductRepository^>^(^);
echo         _uowMock = new Mock^<IUnitOfWork^>^(^);
echo         _dispatcherMock = new Mock^<IDomainEventDispatcher^>^(^);
echo         _handler = new UpdateProductPriceCommandHandler^(
echo             _productRepoMock.Object,
echo             _uowMock.Object,
echo             _dispatcherMock.Object^);
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldReturnFalse_WhenProductNotFound^(^)
echo     {
echo         // Arrange
echo         _productRepoMock
echo             .Setup^(r =^> r.GetByIdAsync^(It.IsAny^<ProductId^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(^(Product?^)null^);
echo.
echo         var command = new UpdateProductPriceCommand { ProductId = 99, NewPrice = 50, Currency = "USD" };
echo.
echo         // Act
echo         var result = await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).BeFalse^(^);
echo         _uowMock.Verify^(u =^> u.SaveChangesAsync^(It.IsAny^<CancellationToken^>^(^)^), Times.Never^);
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldUpdatePrice_WhenProductExists^(^)
echo     {
echo         // Arrange
echo         var product = new Product^(ProductId.From^(1^), "Laptop", new Money^(1000^), "Desc"^);
echo         _productRepoMock
echo             .Setup^(r =^> r.GetByIdAsync^(It.IsAny^<ProductId^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(product^);
echo.
echo         var command = new UpdateProductPriceCommand { ProductId = 1, NewPrice = 1200, Currency = "USD" };
echo.
echo         // Act
echo         var result = await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).BeTrue^(^);
echo         product.Price.Amount.Should^(^).Be^(1200^);
echo         _uowMock.Verify^(u =^> u.SaveChangesAsync^(It.IsAny^<CancellationToken^>^(^)^), Times.Once^);
echo     }
echo }
) > "%projectName%.Application.Tests\UpdateProductPriceCommandHandlerTests.cs"

REM --- AddStockCommandHandlerTests ---
(
echo using Moq;
echo using FluentAssertions;
echo using %projectName%.Application.Commands.Products;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Application.Tests;
echo.
echo public class AddStockCommandHandlerTests
echo {
echo     private readonly Mock^<IProductRepository^> _productRepoMock;
echo     private readonly Mock^<IUnitOfWork^> _uowMock;
echo     private readonly Mock^<IDomainEventDispatcher^> _dispatcherMock;
echo     private readonly AddStockCommandHandler _handler;
echo.
echo     public AddStockCommandHandlerTests^(^)
echo     {
echo         _productRepoMock = new Mock^<IProductRepository^>^(^);
echo         _uowMock = new Mock^<IUnitOfWork^>^(^);
echo         _dispatcherMock = new Mock^<IDomainEventDispatcher^>^(^);
echo         _handler = new AddStockCommandHandler^(
echo             _productRepoMock.Object,
echo             _uowMock.Object,
echo             _dispatcherMock.Object^);
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldIncreaseStock_WhenProductExists^(^)
echo     {
echo         // Arrange
echo         var product = new Product^(ProductId.From^(1^), "Widget", new Money^(10^), "Desc", 5^);
echo         _productRepoMock
echo             .Setup^(r =^> r.GetByIdAsync^(It.IsAny^<ProductId^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(product^);
echo.
echo         var command = new AddStockCommand { ProductId = 1, Quantity = 10 };
echo.
echo         // Act
echo         var result = await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).BeTrue^(^);
echo         product.Stock.Should^(^).Be^(15^);
echo         _uowMock.Verify^(u =^> u.SaveChangesAsync^(It.IsAny^<CancellationToken^>^(^)^), Times.Once^);
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldReturnFalse_WhenProductNotFound^(^)
echo     {
echo         // Arrange
echo         _productRepoMock
echo             .Setup^(r =^> r.GetByIdAsync^(It.IsAny^<ProductId^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(^(Product?^)null^);
echo.
echo         var command = new AddStockCommand { ProductId = 999, Quantity = 5 };
echo.
echo         // Act
echo         var result = await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).BeFalse^(^);
echo     }
echo }
) > "%projectName%.Application.Tests\AddStockCommandHandlerTests.cs"

REM --- ProductQueryHandlerTests (Light usa IProductRepository + AutoMapper) ---
(
echo using AutoMapper;
echo using Moq;
echo using FluentAssertions;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.DTOs;
echo using %projectName%.Application.Queries.Products;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Application.Tests;
echo.
echo public class ProductQueryHandlerTests
echo {
echo     private readonly Mock^<IProductRepository^> _repoMock;
echo     private readonly Mock^<IMapper^> _mapperMock;
echo.
echo     public ProductQueryHandlerTests^(^)
echo     {
echo         _repoMock = new Mock^<IProductRepository^>^(^);
echo         _mapperMock = new Mock^<IMapper^>^(^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetProductsQueryHandler_ShouldReturnAllProducts^(^)
echo     {
echo         // Arrange
echo         var products = new List^<Product^>
echo         {
echo             new Product^(ProductId.From^(1^), "Prod A", new Money^(10^), "Desc"^),
echo             new Product^(ProductId.From^(2^), "Prod B", new Money^(20^), "Desc"^)
echo         };
echo         _repoMock.Setup^(r =^> r.GetAllAsync^(It.IsAny^<CancellationToken^>^(^)^)^).ReturnsAsync^(products^);
echo         _mapperMock.Setup^(m =^> m.Map^<IEnumerable^<ProductDto^>^>^(products^)^).Returns^(new List^<ProductDto^>^(^)^);
echo.
echo         var handler = new GetProductsQueryHandler^(_repoMock.Object, _mapperMock.Object^);
echo.
echo         // Act
echo         var result = await handler.Handle^(new GetProductsQuery^(^), CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetProductByIdQueryHandler_ShouldReturnNull_WhenNotFound^(^)
echo     {
echo         // Arrange
echo         _repoMock.Setup^(r =^> r.GetByIdAsync^(It.IsAny^<ProductId^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo                  .ReturnsAsync^(^(Product?^)null^);
echo         _mapperMock.Setup^(m =^> m.Map^<ProductDto^>^(null^)^).Returns^(^(ProductDto^)null!^);
echo.
echo         var handler = new GetProductByIdQueryHandler^(_repoMock.Object, _mapperMock.Object^);
echo.
echo         // Act
echo         var result = await handler.Handle^(new GetProductByIdQuery^(99^), CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).BeNull^(^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetProductByIdQueryHandler_ShouldReturnDto_WhenFound^(^)
echo     {
echo         // Arrange
echo         var product = new Product^(ProductId.From^(1^), "Laptop", new Money^(999^), "Desc"^);
echo         var dto = new ProductDto { Id = 1, Name = "Laptop", Price = 999 };
echo         _repoMock.Setup^(r =^> r.GetByIdAsync^(It.IsAny^<ProductId^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo                  .ReturnsAsync^(product^);
echo         _mapperMock.Setup^(m =^> m.Map^<ProductDto^>^(product^)^).Returns^(dto^);
echo.
echo         var handler = new GetProductByIdQueryHandler^(_repoMock.Object, _mapperMock.Object^);
echo.
echo         // Act
echo         var result = await handler.Handle^(new GetProductByIdQuery^(1^), CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result!.Name.Should^(^).Be^("Laptop"^);
echo         result.Price.Should^(^).Be^(999^);
echo     }
echo }
) > "%projectName%.Application.Tests\ProductQueryHandlerTests.cs"

) else (

REM --- Tests para CQRS Real (EF o Dapper): CommandHandlers usan IProductWriteRepository ---
(
echo using Moq;
echo using FluentAssertions;
echo using %projectName%.Application.Commands.Products;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Application.Tests;
echo.
echo public class CreateProductCommandHandlerTests
echo {
echo     private readonly Mock^<IProductWriteRepository^> _productRepoMock;
echo     private readonly Mock^<IUnitOfWork^> _uowMock;
echo     private readonly Mock^<IDomainEventDispatcher^> _dispatcherMock;
echo     private readonly CreateProductCommandHandler _handler;
echo.
echo     public CreateProductCommandHandlerTests^(^)
echo     {
echo         _productRepoMock = new Mock^<IProductWriteRepository^>^(^);
echo         _uowMock = new Mock^<IUnitOfWork^>^(^);
echo         _dispatcherMock = new Mock^<IDomainEventDispatcher^>^(^);
echo         _handler = new CreateProductCommandHandler^(
echo             _productRepoMock.Object,
echo             _uowMock.Object,
echo             _dispatcherMock.Object^);
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldCreateProduct_AndSaveInRepository^(^)
echo     {
echo         // Arrange
echo         var command = new CreateProductCommand
echo         {
echo             Name = "Test Product",
echo             Price = 100,
echo             Currency = "USD",
echo             Description = "Test Desc"
echo         };
echo.
echo         // Act
echo         var result = await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         _productRepoMock.Verify^(r =^> r.AddAsync^(It.IsAny^<Product^>^(^), It.IsAny^<CancellationToken^>^(^)^), Times.Once^);
echo         _uowMock.Verify^(u =^> u.SaveChangesAsync^(It.IsAny^<CancellationToken^>^(^)^), Times.Once^);
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldReturnProductId_WhenProductIsCreated^(^)
echo     {
echo         // Arrange
echo         var command = new CreateProductCommand
echo         {
echo             Name = "My Product",
echo             Price = 250,
echo             Currency = "USD",
echo             Description = "Description"
echo         };
echo.
echo         // Act
echo         var result = await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).BeOfType^<ProductId^>^(^);
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldDispatchDomainEvents_AfterSave^(^)
echo     {
echo         // Arrange
echo         var command = new CreateProductCommand
echo         {
echo             Name = "Event Product",
echo             Price = 10,
echo             Currency = "USD",
echo             Description = ""
echo         };
echo.
echo         // Act
echo         await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         _dispatcherMock.Verify^(
echo             d =^> d.DispatchAsync^(It.IsAny^<IEnumerable^<IDomainEvent^>^>^(^), It.IsAny^<CancellationToken^>^(^)^),
echo             Times.Once^);
echo     }
echo }
) > "%projectName%.Application.Tests\CreateProductCommandHandlerTests.cs"

(
echo using Moq;
echo using FluentAssertions;
echo using %projectName%.Application.Commands.Products;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Application.Tests;
echo.
echo public class UpdateProductPriceCommandHandlerTests
echo {
echo     private readonly Mock^<IProductWriteRepository^> _productRepoMock;
echo     private readonly Mock^<IUnitOfWork^> _uowMock;
echo     private readonly Mock^<IDomainEventDispatcher^> _dispatcherMock;
echo     private readonly UpdateProductPriceCommandHandler _handler;
echo.
echo     public UpdateProductPriceCommandHandlerTests^(^)
echo     {
echo         _productRepoMock = new Mock^<IProductWriteRepository^>^(^);
echo         _uowMock = new Mock^<IUnitOfWork^>^(^);
echo         _dispatcherMock = new Mock^<IDomainEventDispatcher^>^(^);
echo         _handler = new UpdateProductPriceCommandHandler^(
echo             _productRepoMock.Object,
echo             _uowMock.Object,
echo             _dispatcherMock.Object^);
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldReturnFalse_WhenProductNotFound^(^)
echo     {
echo         // Arrange
echo         _productRepoMock
echo             .Setup^(r =^> r.GetByIdAsync^(It.IsAny^<ProductId^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(^(Product?^)null^);
echo.
echo         var command = new UpdateProductPriceCommand { ProductId = 99, NewPrice = 50, Currency = "USD" };
echo.
echo         // Act
echo         var result = await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).BeFalse^(^);
echo         _uowMock.Verify^(u =^> u.SaveChangesAsync^(It.IsAny^<CancellationToken^>^(^)^), Times.Never^);
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldUpdatePrice_WhenProductExists^(^)
echo     {
echo         // Arrange
echo         var product = new Product^(ProductId.From^(1^), "Laptop", new Money^(1000^), "Desc"^);
echo         _productRepoMock
echo             .Setup^(r =^> r.GetByIdAsync^(It.IsAny^<ProductId^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(product^);
echo.
echo         var command = new UpdateProductPriceCommand { ProductId = 1, NewPrice = 1200, Currency = "USD" };
echo.
echo         // Act
echo         var result = await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).BeTrue^(^);
echo         product.Price.Amount.Should^(^).Be^(1200^);
echo         _uowMock.Verify^(u =^> u.SaveChangesAsync^(It.IsAny^<CancellationToken^>^(^)^), Times.Once^);
echo     }
echo.
echo     [Fact]
echo     public async Task Handle_ShouldDispatchPriceChangedEvent_WhenProductUpdated^(^)
echo     {
echo         // Arrange
echo         var product = new Product^(ProductId.From^(1^), "Tablet", new Money^(500^), "Desc"^);
echo         _productRepoMock
echo             .Setup^(r =^> r.GetByIdAsync^(It.IsAny^<ProductId^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(product^);
echo.
echo         var command = new UpdateProductPriceCommand { ProductId = 1, NewPrice = 600, Currency = "USD" };
echo.
echo         // Act
echo         await _handler.Handle^(command, CancellationToken.None^);
echo.
echo         // Assert
echo         _dispatcherMock.Verify^(
echo             d =^> d.DispatchAsync^(It.IsAny^<IEnumerable^<IDomainEvent^>^>^(^), It.IsAny^<CancellationToken^>^(^)^),
echo             Times.Once^);
echo     }
echo }
) > "%projectName%.Application.Tests\UpdateProductPriceCommandHandlerTests.cs"

REM --- Query Handlers tests para CQRS Real con EF ---
if NOT "%useDapper%"=="true" (
(
echo using Moq;
echo using FluentAssertions;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.Queries.Products;
echo using %projectName%.Application.ReadModels;
echo using Xunit;
echo.
echo namespace %projectName%.Application.Tests;
echo.
echo public class ProductQueryHandlerTests
echo {
echo     private readonly Mock^<IProductReadRepository^> _readRepoMock;
echo.
echo     public ProductQueryHandlerTests^(^)
echo     {
echo         _readRepoMock = new Mock^<IProductReadRepository^>^(^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetProductsQueryHandler_ShouldReturnAllReadModels^(^)
echo     {
echo         // Arrange
echo         var readModels = new List^<ProductReadModel^>
echo         {
echo             new ProductReadModel { Id = 1, Name = "Prod A", Price = 10 },
echo             new ProductReadModel { Id = 2, Name = "Prod B", Price = 20 }
echo         };
echo         _readRepoMock.Setup^(r =^> r.GetAllAsync^(It.IsAny^<CancellationToken^>^(^)^)^).ReturnsAsync^(readModels^);
echo.
echo         var handler = new GetProductsQueryHandler^(_readRepoMock.Object^);
echo.
echo         // Act
echo         var result = await handler.Handle^(new GetProductsQuery^(^), CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).HaveCount^(2^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetProductByIdQueryHandler_ShouldReturnModel_WhenFound^(^)
echo     {
echo         // Arrange
echo         var model = new ProductReadModel { Id = 1, Name = "Laptop", Price = 999, IsActive = true };
echo         _readRepoMock.Setup^(r =^> r.GetByIdAsync^(1, It.IsAny^<CancellationToken^>^(^)^)^).ReturnsAsync^(model^);
echo.
echo         var handler = new GetProductByIdQueryHandler^(_readRepoMock.Object^);
echo.
echo         // Act
echo         var result = await handler.Handle^(new GetProductByIdQuery^(1^), CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result!.Name.Should^(^).Be^("Laptop"^);
echo         result.Price.Should^(^).Be^(999^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetProductByIdQueryHandler_ShouldReturnNull_WhenNotFound^(^)
echo     {
echo         // Arrange
echo         _readRepoMock.Setup^(r =^> r.GetByIdAsync^(99, It.IsAny^<CancellationToken^>^(^)^)^)
echo                      .ReturnsAsync^(^(ProductReadModel?^)null^);
echo.
echo         var handler = new GetProductByIdQueryHandler^(_readRepoMock.Object^);
echo.
echo         // Act
echo         var result = await handler.Handle^(new GetProductByIdQuery^(99^), CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).BeNull^(^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetActiveProductsQueryHandler_ShouldReturnOnlyActiveProducts^(^)
echo     {
echo         // Arrange
echo         var active = new List^<ProductReadModel^>
echo         {
echo             new ProductReadModel { Id = 1, Name = "Active A", IsActive = true }
echo         };
echo         _readRepoMock.Setup^(r =^> r.FindAsync^(It.IsAny^<System.Linq.Expressions.Expression^<System.Func^<ProductReadModel, bool^>^>^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo                      .ReturnsAsync^(active^);
echo.
echo         var handler = new GetActiveProductsQueryHandler^(_readRepoMock.Object^);
echo.
echo         // Act
echo         var result = await handler.Handle^(new GetActiveProductsQuery^(^), CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).HaveCount^(1^);
echo         result.First^(^).IsActive.Should^(^).BeTrue^(^);
echo     }
echo }
) > "%projectName%.Application.Tests\ProductQueryHandlerTests.cs"
)

REM --- Query Handlers tests para CQRS Real Dapper ---
if "%useDapper%"=="true" (
(
echo using Moq;
echo using FluentAssertions;
echo using %projectName%.Application.Common.Interfaces;
echo using %projectName%.Application.Queries.Products;
echo using %projectName%.Application.ReadModels;
echo using Xunit;
echo.
echo namespace %projectName%.Application.Tests;
echo.
echo public class ProductQueryHandlerTests
echo {
echo     private readonly Mock^<IQueryService^> _queryServiceMock;
echo.
echo     public ProductQueryHandlerTests^(^)
echo     {
echo         _queryServiceMock = new Mock^<IQueryService^>^(^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetProductsQueryHandler_ShouldCallQueryAsync^(^)
echo     {
echo         // Arrange
echo         var models = new List^<ProductReadModel^>
echo         {
echo             new ProductReadModel { Id = 1, Name = "Prod A", Price = 10 },
echo             new ProductReadModel { Id = 2, Name = "Prod B", Price = 20 }
echo         };
echo         _queryServiceMock
echo             .Setup^(q =^> q.QueryAsync^<ProductReadModel^>^(It.IsAny^<string^>^(^), null, It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(models^);
echo.
echo         var handler = new GetProductsQueryHandler^(_queryServiceMock.Object^);
echo.
echo         // Act
echo         var result = await handler.Handle^(new GetProductsQuery^(^), CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).HaveCount^(2^);
echo         _queryServiceMock.Verify^(q =^> q.QueryAsync^<ProductReadModel^>^(It.IsAny^<string^>^(^), null, It.IsAny^<CancellationToken^>^(^)^), Times.Once^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetProductByIdQueryHandler_ShouldCallQuerySingleAsync^(^)
echo     {
echo         // Arrange
echo         var model = new ProductReadModel { Id = 5, Name = "Monitor", Price = 300 };
echo         _queryServiceMock
echo             .Setup^(q =^> q.QuerySingleAsync^<ProductReadModel^>^(It.IsAny^<string^>^(^), It.IsAny^<object^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(model^);
echo.
echo         var handler = new GetProductByIdQueryHandler^(_queryServiceMock.Object^);
echo.
echo         // Act
echo         var result = await handler.Handle^(new GetProductByIdQuery^(5^), CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result!.Name.Should^(^).Be^("Monitor"^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetActiveProductsQueryHandler_ShouldReturnFilteredModels^(^)
echo     {
echo         // Arrange
echo         var active = new List^<ProductReadModel^>
echo         {
echo             new ProductReadModel { Id = 1, Name = "Active", IsActive = true }
echo         };
echo         _queryServiceMock
echo             .Setup^(q =^> q.QueryAsync^<ProductReadModel^>^(It.IsAny^<string^>^(^), null, It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(active^);
echo.
echo         var handler = new GetActiveProductsQueryHandler^(_queryServiceMock.Object^);
echo.
echo         // Act
echo         var result = await handler.Handle^(new GetActiveProductsQuery^(^), CancellationToken.None^);
echo.
echo         // Assert
echo         result.Should^(^).HaveCount^(1^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetProductsByPriceRangeQueryHandler_ShouldPassParameters^(^)
echo     {
echo         // Arrange
echo         _queryServiceMock
echo             .Setup^(q =^> q.QueryAsync^<ProductReadModel^>^(It.IsAny^<string^>^(^), It.IsAny^<object^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(new List^<ProductReadModel^>^(^)^);
echo.
echo         var handler = new GetProductsByPriceRangeQueryHandler^(_queryServiceMock.Object^);
echo.
echo         // Act
echo         var result = await handler.Handle^(new GetProductsByPriceRangeQuery^(10, 500^), CancellationToken.None^);
echo.
echo         // Assert
echo         _queryServiceMock.Verify^(
echo             q =^> q.QueryAsync^<ProductReadModel^>^(It.IsAny^<string^>^(^), It.IsAny^<object^>^(^), It.IsAny^<CancellationToken^>^(^)^),
echo             Times.Once^);
echo     }
echo }
) > "%projectName%.Application.Tests\ProductQueryHandlerTests.cs"
)

)

REM ============================================================
REM === GENERANDO TESTS DE DOMAIN (sin BD, sin mocks) ===
REM ============================================================

(
echo using FluentAssertions;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Application.Tests;
echo.
echo public class ProductDomainTests
echo {
echo     [Fact]
echo     public void CreateProduct_ShouldSetProperties_Correctly^(^)
echo     {
echo         // Arrange ^& Act
echo         var product = new Product^(ProductId.From^(1^), "Laptop", new Money^(999, "USD"^), "Desc"^);
echo.
echo         // Assert
echo         product.Name.Should^(^).Be^("Laptop"^);
echo         product.Price.Amount.Should^(^).Be^(999^);
echo         product.Price.Currency.Should^(^).Be^("USD"^);
echo         product.IsActive.Should^(^).BeTrue^(^);
echo         product.Stock.Should^(^).Be^(0^);
echo     }
echo.
echo     [Fact]
echo     public void CreateProduct_ShouldRaiseDomainEvent_OnCreation^(^)
echo     {
echo         // Act
echo         var product = new Product^(ProductId.From^(1^), "Tablet", new Money^(500^), "Desc"^);
echo.
echo         // Assert
echo         product.DomainEvents.Should^(^).HaveCount^(1^);
echo         product.DomainEvents.First^(^).Should^(^).BeOfType^<ProductCreatedEvent^>^(^);
echo     }
echo.
echo     [Fact]
echo     public void UpdatePrice_ShouldChangePrice_AndRaiseEvent^(^)
echo     {
echo         // Arrange
echo         var product = new Product^(ProductId.From^(1^), "Mouse", new Money^(30^), "Desc"^);
echo         product.ClearDomainEvents^(^);
echo.
echo         // Act
echo         product.UpdatePrice^(new Money^(45^)^);
echo.
echo         // Assert
echo         product.Price.Amount.Should^(^).Be^(45^);
echo         product.DomainEvents.Should^(^).ContainSingle^(^);
echo         product.DomainEvents.First^(^).Should^(^).BeOfType^<ProductPriceChangedEvent^>^(^);
echo     }
echo.
echo     [Fact]
echo     public void AddStock_ShouldIncreaseStock_AndRaiseEvent^(^)
echo     {
echo         // Arrange
echo         var product = new Product^(ProductId.From^(1^), "Keyboard", new Money^(50^), "Desc", 10^);
echo         product.ClearDomainEvents^(^);
echo.
echo         // Act
echo         product.AddStock^(5^);
echo.
echo         // Assert
echo         product.Stock.Should^(^).Be^(15^);
echo         product.DomainEvents.First^(^).Should^(^).BeOfType^<StockAddedEvent^>^(^);
echo     }
echo.
echo     [Fact]
echo     public void RemoveStock_ShouldThrow_WhenInsufficientStock^(^)
echo     {
echo         // Arrange
echo         var product = new Product^(ProductId.From^(1^), "Headset", new Money^(80^), "Desc", 3^);
echo.
echo         // Act
echo         var act = ^(^) =^> product.RemoveStock^(10^);
echo.
echo         // Assert
echo         act.Should^(^).Throw^<DomainException^>^(^)
echo            .WithMessage^("*Insufficient stock*"^);
echo     }
echo.
echo     [Fact]
echo     public void Deactivate_ShouldSetIsActiveFalse_AndRaiseEvent^(^)
echo     {
echo         // Arrange
echo         var product = new Product^(ProductId.From^(1^), "Monitor", new Money^(300^), "Desc"^);
echo         product.ClearDomainEvents^(^);
echo.
echo         // Act
echo         product.Deactivate^(^);
echo.
echo         // Assert
echo         product.IsActive.Should^(^).BeFalse^(^);
echo         product.DomainEvents.First^(^).Should^(^).BeOfType^<ProductDeactivatedEvent^>^(^);
echo     }
echo.
echo     [Fact]
echo     public void Money_Add_ShouldSumAmounts_WhenSameCurrency^(^)
echo     {
echo         // Arrange
echo         var a = new Money^(100, "USD"^);
echo         var b = new Money^(50, "USD"^);
echo.
echo         // Act
echo         var result = a.Add^(b^);
echo.
echo         // Assert
echo         result.Amount.Should^(^).Be^(150^);
echo         result.Currency.Should^(^).Be^("USD"^);
echo     }
echo.
echo     [Fact]
echo     public void Money_Add_ShouldThrow_WhenDifferentCurrencies^(^)
echo     {
echo         // Arrange
echo         var usd = new Money^(100, "USD"^);
echo         var eur = new Money^(50, "EUR"^);
echo.
echo         // Act
echo         var act = ^(^) =^> usd.Add^(eur^);
echo.
echo         // Assert
echo         act.Should^(^).Throw^<DomainException^>^(^);
echo     }
echo.
echo     [Fact]
echo     public void ProductId_Equality_ShouldWork_AsValueObject^(^)
echo     {
echo         // Arrange
echo         var id1 = ProductId.From^(42^);
echo         var id2 = ProductId.From^(42^);
echo         var id3 = ProductId.From^(99^);
echo.
echo         // Assert
echo         id1.Should^(^).Be^(id2^);
echo         id1.Should^(^).NotBe^(id3^);
echo     }
echo }
) > "%projectName%.Application.Tests\ProductDomainTests.cs"

REM ============================================================
REM === GENERANDO TESTS DE INFRASTRUCTURE ===
REM ============================================================

if "%cqrsMode%"=="Light" (

REM --- ProductRepositoryTests (Light - ApplicationDbContext) ---
(
echo using Microsoft.EntityFrameworkCore;
echo using FluentAssertions;
echo using %projectName%.Infrastructure.Persistence;
echo using %projectName%.Infrastructure.Persistence.Repositories;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Infrastructure.Tests;
echo.
echo public class ProductRepositoryTests
echo {
echo     private ApplicationDbContext GetDbContext^(^)
echo     {
echo         var options = new DbContextOptionsBuilder^<ApplicationDbContext^>^(^)
echo             .UseInMemoryDatabase^(databaseName: Guid.NewGuid^(^).ToString^(^)^)
echo             .Options;
echo         return new ApplicationDbContext^(options^);
echo     }
echo.
echo     [Fact]
echo     public async Task AddAsync_ShouldPersistProductInDatabase^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new ProductRepository^(context^);
echo         var product = new Product^(ProductId.Create^(^), "Database Product", new Money^(50^), "Desc"^);
echo.
echo         // Act
echo         await repository.AddAsync^(product^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var savedProduct = await context.Products.FirstOrDefaultAsync^(^);
echo         savedProduct.Should^(^).NotBeNull^(^);
echo         savedProduct!.Name.Should^(^).Be^("Database Product"^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetByIdAsync_ShouldReturnProduct_WhenExists^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new ProductRepository^(context^);
echo         var product = new Product^(ProductId.From^(1^), "Laptop", new Money^(999^), "Desc"^);
echo         await context.Products.AddAsync^(product^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         var result = await repository.GetByIdAsync^(ProductId.From^(1^)^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result!.Name.Should^(^).Be^("Laptop"^);
echo         result.Price.Amount.Should^(^).Be^(999^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetByIdAsync_ShouldReturnNull_WhenNotExists^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new ProductRepository^(context^);
echo.
echo         // Act
echo         var result = await repository.GetByIdAsync^(ProductId.From^(999^)^);
echo.
echo         // Assert
echo         result.Should^(^).BeNull^(^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetAllAsync_ShouldReturnAllProducts^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new ProductRepository^(context^);
echo         await context.Products.AddRangeAsync^(
echo             new Product^(ProductId.From^(1^), "Prod A", new Money^(10^), "Desc"^),
echo             new Product^(ProductId.From^(2^), "Prod B", new Money^(20^), "Desc"^),
echo             new Product^(ProductId.From^(3^), "Prod C", new Money^(30^), "Desc"^)
echo         ^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         var result = await repository.GetAllAsync^(^);
echo.
echo         // Assert
echo         result.Should^(^).HaveCount^(3^);
echo     }
echo.
echo     [Fact]
echo     public async Task UpdateAsync_ShouldPersistPriceChange^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new ProductRepository^(context^);
echo         var product = new Product^(ProductId.From^(1^), "Widget", new Money^(100^), "Desc"^);
echo         await context.Products.AddAsync^(product^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         product.UpdatePrice^(new Money^(200^)^);
echo         await repository.UpdateAsync^(product^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var updated = await context.Products.FindAsync^(ProductId.From^(1^)^);
echo         updated!.Price.Amount.Should^(^).Be^(200^);
echo     }
echo.
echo     [Fact]
echo     public async Task DeleteAsync_ShouldRemoveProduct^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new ProductRepository^(context^);
echo         var product = new Product^(ProductId.From^(1^), "To Delete", new Money^(10^), "Desc"^);
echo         await context.Products.AddAsync^(product^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         await repository.DeleteAsync^(product^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var count = await context.Products.CountAsync^(^);
echo         count.Should^(^).Be^(0^);
echo     }
echo }
) > "%projectName%.Infrastructure.Tests\ProductRepositoryTests.cs"

REM --- CustomerRepositoryTests (Light) ---
(
echo using Microsoft.EntityFrameworkCore;
echo using FluentAssertions;
echo using %projectName%.Infrastructure.Persistence;
echo using %projectName%.Infrastructure.Persistence.Repositories;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Infrastructure.Tests;
echo.
echo public class CustomerRepositoryTests
echo {
echo     private ApplicationDbContext GetDbContext^(^)
echo     {
echo         var options = new DbContextOptionsBuilder^<ApplicationDbContext^>^(^)
echo             .UseInMemoryDatabase^(databaseName: Guid.NewGuid^(^).ToString^(^)^)
echo             .Options;
echo         return new ApplicationDbContext^(options^);
echo     }
echo.
echo     [Fact]
echo     public async Task AddAsync_ShouldPersistCustomerInDatabase^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new CustomerRepository^(context^);
echo         var customer = new Customer^(
echo             CustomerId.Create^(^),
echo             "John",
echo             "Doe",
echo             new Email^("john.doe@example.com"^)^);
echo.
echo         // Act
echo         await repository.AddAsync^(customer^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var saved = await context.Customers.FirstOrDefaultAsync^(^);
echo         saved.Should^(^).NotBeNull^(^);
echo         saved!.FirstName.Should^(^).Be^("John"^);
echo         saved.LastName.Should^(^).Be^("Doe"^);
echo         saved.Email.Address.Should^(^).Be^("john.doe@example.com"^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetByIdAsync_ShouldReturnCustomer_WhenExists^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new CustomerRepository^(context^);
echo         var customer = new Customer^(CustomerId.From^(1^), "Jane", "Smith", new Email^("jane@example.com"^)^);
echo         await context.Customers.AddAsync^(customer^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         var result = await repository.GetByIdAsync^(CustomerId.From^(1^)^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result!.GetFullName^(^).Should^(^).Be^("Jane Smith"^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetByIdAsync_ShouldReturnNull_WhenNotExists^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new CustomerRepository^(context^);
echo.
echo         // Act
echo         var result = await repository.GetByIdAsync^(CustomerId.From^(999^)^);
echo.
echo         // Assert
echo         result.Should^(^).BeNull^(^);
echo     }
echo.
echo     [Fact]
echo     public async Task UpdateEmail_ShouldPersistNewEmail^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new CustomerRepository^(context^);
echo         var customer = new Customer^(CustomerId.From^(1^), "Alice", "Brown", new Email^("old@example.com"^)^);
echo         await context.Customers.AddAsync^(customer^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         customer.UpdateEmail^(new Email^("new@example.com"^)^);
echo         await repository.UpdateAsync^(customer^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var updated = await context.Customers.FindAsync^(CustomerId.From^(1^)^);
echo         updated!.Email.Address.Should^(^).Be^("new@example.com"^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetAllAsync_ShouldReturnAllCustomers^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new CustomerRepository^(context^);
echo         await context.Customers.AddRangeAsync^(
echo             new Customer^(CustomerId.From^(1^), "Alice", "A", new Email^("a@x.com"^)^),
echo             new Customer^(CustomerId.From^(2^), "Bob",   "B", new Email^("b@x.com"^)^)
echo         ^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         var result = await repository.GetAllAsync^(^);
echo.
echo         // Assert
echo         result.Should^(^).HaveCount^(2^);
echo     }
echo }
) > "%projectName%.Infrastructure.Tests\CustomerRepositoryTests.cs"

REM --- OrderRepositoryTests (Light) ---
(
echo using Microsoft.EntityFrameworkCore;
echo using FluentAssertions;
echo using %projectName%.Infrastructure.Persistence;
echo using %projectName%.Infrastructure.Persistence.Repositories;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Infrastructure.Tests;
echo.
echo public class OrderRepositoryTests
echo {
echo     private ApplicationDbContext GetDbContext^(^)
echo     {
echo         var options = new DbContextOptionsBuilder^<ApplicationDbContext^>^(^)
echo             .UseInMemoryDatabase^(databaseName: Guid.NewGuid^(^).ToString^(^)^)
echo             .Options;
echo         return new ApplicationDbContext^(options^);
echo     }
echo.
echo     [Fact]
echo     public async Task AddAsync_ShouldPersistOrderInDatabase^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new OrderRepository^(context^);
echo         var order = new Order^(OrderId.Create^(^), CustomerId.From^(1^)^);
echo.
echo         // Act
echo         await repository.AddAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var saved = await context.Orders.FirstOrDefaultAsync^(^);
echo         saved.Should^(^).NotBeNull^(^);
echo         saved!.CustomerId.Value.Should^(^).Be^(1^);
echo         saved.Status.Should^(^).Be^(OrderStatus.Pending^);
echo     }
echo.
echo     [Fact]
echo     public async Task AddAsync_ShouldPersistOrderWithItems^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new OrderRepository^(context^);
echo         var order = new Order^(OrderId.Create^(^), CustomerId.From^(1^)^);
echo         order.AddItem^(ProductId.From^(10^), new Money^(100^), 2^);
echo         order.AddItem^(ProductId.From^(20^), new Money^(50^), 1^);
echo.
echo         // Act
echo         await repository.AddAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var saved = await context.Orders.Include^(o =^> o.Items^).FirstOrDefaultAsync^(^);
echo         saved!.Items.Should^(^).HaveCount^(2^);
echo         saved.GetTotal^(^).Amount.Should^(^).Be^(250^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetByIdAsync_ShouldReturnOrder_WhenExists^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new OrderRepository^(context^);
echo         var order = new Order^(OrderId.From^(1^), CustomerId.From^(5^)^);
echo         await context.Orders.AddAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         var result = await repository.GetByIdAsync^(OrderId.From^(1^)^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result!.CustomerId.Value.Should^(^).Be^(5^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetOrdersByCustomerAsync_ShouldReturnOnlyCustomerOrders^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new OrderRepository^(context^);
echo         await context.Orders.AddRangeAsync^(
echo             new Order^(OrderId.From^(1^), CustomerId.From^(1^)^),
echo             new Order^(OrderId.From^(2^), CustomerId.From^(1^)^),
echo             new Order^(OrderId.From^(3^), CustomerId.From^(2^)^)
echo         ^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         var result = await repository.GetOrdersByCustomerAsync^(CustomerId.From^(1^)^);
echo.
echo         // Assert
echo         result.Should^(^).HaveCount^(2^);
echo         result.All^(o =^> o.CustomerId.Value == 1^).Should^(^).BeTrue^(^);
echo     }
echo.
echo     [Fact]
echo     public async Task Confirm_ShouldChangeStatusToConfirmed^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new OrderRepository^(context^);
echo         var order = new Order^(OrderId.From^(1^), CustomerId.From^(1^)^);
echo         order.AddItem^(ProductId.From^(1^), new Money^(10^), 1^);
echo         await context.Orders.AddAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         order.Confirm^(^);
echo         await repository.UpdateAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var updated = await context.Orders.FindAsync^(OrderId.From^(1^)^);
echo         updated!.Status.Should^(^).Be^(OrderStatus.Confirmed^);
echo     }
echo.
echo     [Fact]
echo     public async Task Cancel_ShouldChangeStatusToCancelled^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new OrderRepository^(context^);
echo         var order = new Order^(OrderId.From^(1^), CustomerId.From^(1^)^);
echo         await context.Orders.AddAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         order.Cancel^(^);
echo         await repository.UpdateAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var updated = await context.Orders.FindAsync^(OrderId.From^(1^)^);
echo         updated!.Status.Should^(^).Be^(OrderStatus.Cancelled^);
echo     }
echo }
) > "%projectName%.Infrastructure.Tests\OrderRepositoryTests.cs"

) else (

REM --- Tests CQRS Real: usan WriteDbContext ---
(
echo using Microsoft.EntityFrameworkCore;
echo using FluentAssertions;
echo using %projectName%.Infrastructure.Persistence;
echo using %projectName%.Infrastructure.Persistence.Repositories;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Infrastructure.Tests;
echo.
echo public class ProductRepositoryTests
echo {
echo     private WriteDbContext GetDbContext^(^)
echo     {
echo         var options = new DbContextOptionsBuilder^<WriteDbContext^>^(^)
echo             .UseInMemoryDatabase^(databaseName: Guid.NewGuid^(^).ToString^(^)^)
echo             .Options;
echo         return new WriteDbContext^(options^);
echo     }
echo.
echo     [Fact]
echo     public async Task AddAsync_ShouldPersistProductInDatabase^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new ProductWriteRepository^(context^);
echo         var product = new Product^(ProductId.Create^(^), "Database Product", new Money^(50^), "Desc"^);
echo.
echo         // Act
echo         await repository.AddAsync^(product^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var saved = await context.Products.FirstOrDefaultAsync^(^);
echo         saved.Should^(^).NotBeNull^(^);
echo         saved!.Name.Should^(^).Be^("Database Product"^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetByIdAsync_ShouldReturnProduct_WhenExists^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new ProductWriteRepository^(context^);
echo         var product = new Product^(ProductId.From^(1^), "Laptop", new Money^(999^), "Desc"^);
echo         await context.Products.AddAsync^(product^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         var result = await repository.GetByIdAsync^(ProductId.From^(1^)^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result!.Price.Amount.Should^(^).Be^(999^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetByIdAsync_ShouldReturnNull_WhenNotExists^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new ProductWriteRepository^(context^);
echo.
echo         // Act
echo         var result = await repository.GetByIdAsync^(ProductId.From^(999^)^);
echo.
echo         // Assert
echo         result.Should^(^).BeNull^(^);
echo     }
echo.
echo     [Fact]
echo     public async Task UpdateAsync_ShouldPersistPriceChange^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new ProductWriteRepository^(context^);
echo         var product = new Product^(ProductId.From^(1^), "Widget", new Money^(100^), "Desc"^);
echo         await context.Products.AddAsync^(product^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         product.UpdatePrice^(new Money^(150^)^);
echo         await repository.UpdateAsync^(product^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var updated = await context.Products.FindAsync^(ProductId.From^(1^)^);
echo         updated!.Price.Amount.Should^(^).Be^(150^);
echo     }
echo.
echo     [Fact]
echo     public async Task DeleteAsync_ShouldRemoveProduct^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new ProductWriteRepository^(context^);
echo         var product = new Product^(ProductId.From^(1^), "To Delete", new Money^(10^), "Desc"^);
echo         await context.Products.AddAsync^(product^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         await repository.DeleteAsync^(product^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         ^(await context.Products.CountAsync^(^)^).Should^(^).Be^(0^);
echo     }
echo }
) > "%projectName%.Infrastructure.Tests\ProductRepositoryTests.cs"

(
echo using Microsoft.EntityFrameworkCore;
echo using FluentAssertions;
echo using %projectName%.Infrastructure.Persistence;
echo using %projectName%.Infrastructure.Persistence.Repositories;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Infrastructure.Tests;
echo.
echo public class CustomerRepositoryTests
echo {
echo     private WriteDbContext GetDbContext^(^)
echo     {
echo         var options = new DbContextOptionsBuilder^<WriteDbContext^>^(^)
echo             .UseInMemoryDatabase^(databaseName: Guid.NewGuid^(^).ToString^(^)^)
echo             .Options;
echo         return new WriteDbContext^(options^);
echo     }
echo.
echo     [Fact]
echo     public async Task AddAsync_ShouldPersistCustomerInDatabase^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new CustomerWriteRepository^(context^);
echo         var customer = new Customer^(
echo             CustomerId.Create^(^), "John", "Doe", new Email^("john.doe@example.com"^)^);
echo.
echo         // Act
echo         await repository.AddAsync^(customer^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var saved = await context.Customers.FirstOrDefaultAsync^(^);
echo         saved.Should^(^).NotBeNull^(^);
echo         saved!.FirstName.Should^(^).Be^("John"^);
echo         saved.Email.Address.Should^(^).Be^("john.doe@example.com"^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetByIdAsync_ShouldReturnCustomer_WhenExists^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new CustomerWriteRepository^(context^);
echo         var customer = new Customer^(CustomerId.From^(1^), "Jane", "Smith", new Email^("jane@example.com"^)^);
echo         await context.Customers.AddAsync^(customer^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         var result = await repository.GetByIdAsync^(CustomerId.From^(1^)^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result!.GetFullName^(^).Should^(^).Be^("Jane Smith"^);
echo     }
echo.
echo     [Fact]
echo     public async Task UpdateEmail_ShouldPersistNewEmail^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new CustomerWriteRepository^(context^);
echo         var customer = new Customer^(CustomerId.From^(1^), "Alice", "Brown", new Email^("old@example.com"^)^);
echo         await context.Customers.AddAsync^(customer^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         customer.UpdateEmail^(new Email^("new@example.com"^)^);
echo         await repository.UpdateAsync^(customer^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var updated = await context.Customers.FindAsync^(CustomerId.From^(1^)^);
echo         updated!.Email.Address.Should^(^).Be^("new@example.com"^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetAllAsync_ShouldReturnAllCustomers^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         await context.Customers.AddRangeAsync^(
echo             new Customer^(CustomerId.From^(1^), "Alice", "A", new Email^("a@x.com"^)^),
echo             new Customer^(CustomerId.From^(2^), "Bob",   "B", new Email^("b@x.com"^)^)
echo         ^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         var result = await context.Customers.ToListAsync^(^);
echo.
echo         // Assert
echo         result.Should^(^).HaveCount^(2^);
echo     }
echo }
) > "%projectName%.Infrastructure.Tests\CustomerRepositoryTests.cs"

(
echo using Microsoft.EntityFrameworkCore;
echo using FluentAssertions;
echo using %projectName%.Infrastructure.Persistence;
echo using %projectName%.Infrastructure.Persistence.Repositories;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Infrastructure.Tests;
echo.
echo public class OrderRepositoryTests
echo {
echo     private WriteDbContext GetDbContext^(^)
echo     {
echo         var options = new DbContextOptionsBuilder^<WriteDbContext^>^(^)
echo             .UseInMemoryDatabase^(databaseName: Guid.NewGuid^(^).ToString^(^)^)
echo             .Options;
echo         return new WriteDbContext^(options^);
echo     }
echo.
echo     [Fact]
echo     public async Task AddAsync_ShouldPersistOrderInDatabase^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new OrderWriteRepository^(context^);
echo         var order = new Order^(OrderId.Create^(^), CustomerId.From^(1^)^);
echo.
echo         // Act
echo         await repository.AddAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var saved = await context.Orders.FirstOrDefaultAsync^(^);
echo         saved.Should^(^).NotBeNull^(^);
echo         saved!.CustomerId.Value.Should^(^).Be^(1^);
echo         saved.Status.Should^(^).Be^(OrderStatus.Pending^);
echo     }
echo.
echo     [Fact]
echo     public async Task AddAsync_ShouldPersistOrderWithItems^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new OrderWriteRepository^(context^);
echo         var order = new Order^(OrderId.Create^(^), CustomerId.From^(1^)^);
echo         order.AddItem^(ProductId.From^(10^), new Money^(100^), 2^);
echo         order.AddItem^(ProductId.From^(20^), new Money^(50^),  1^);
echo.
echo         // Act
echo         await repository.AddAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var saved = await context.Orders.Include^(o =^> o.Items^).FirstOrDefaultAsync^(^);
echo         saved!.Items.Should^(^).HaveCount^(2^);
echo         saved.GetTotal^(^).Amount.Should^(^).Be^(250^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetByIdAsync_ShouldReturnOrder_WhenExists^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new OrderWriteRepository^(context^);
echo         var order = new Order^(OrderId.From^(1^), CustomerId.From^(5^)^);
echo         await context.Orders.AddAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         var result = await repository.GetByIdAsync^(OrderId.From^(1^)^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result!.CustomerId.Value.Should^(^).Be^(5^);
echo     }
echo.
echo     [Fact]
echo     public async Task Confirm_ShouldChangeStatusToConfirmed^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new OrderWriteRepository^(context^);
echo         var order = new Order^(OrderId.From^(1^), CustomerId.From^(1^)^);
echo         order.AddItem^(ProductId.From^(1^), new Money^(10^), 1^);
echo         await context.Orders.AddAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         order.Confirm^(^);
echo         await repository.UpdateAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var updated = await context.Orders.FindAsync^(OrderId.From^(1^)^);
echo         updated!.Status.Should^(^).Be^(OrderStatus.Confirmed^);
echo     }
echo.
echo     [Fact]
echo     public async Task Cancel_ShouldChangeStatusToCancelled^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new OrderWriteRepository^(context^);
echo         var order = new Order^(OrderId.From^(1^), CustomerId.From^(1^)^);
echo         await context.Orders.AddAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         order.Cancel^(^);
echo         await repository.UpdateAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var updated = await context.Orders.FindAsync^(OrderId.From^(1^)^);
echo         updated!.Status.Should^(^).Be^(OrderStatus.Cancelled^);
echo     }
echo.
echo     [Fact]
echo     public async Task DeleteAsync_ShouldRemoveOrder^(^)
echo     {
echo         // Arrange
echo         var context = GetDbContext^(^);
echo         var repository = new OrderWriteRepository^(context^);
echo         var order = new Order^(OrderId.From^(1^), CustomerId.From^(1^)^);
echo         await context.Orders.AddAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         await repository.DeleteAsync^(order^);
echo         await context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         ^(await context.Orders.CountAsync^(^)^).Should^(^).Be^(0^);
echo     }
echo }
) > "%projectName%.Infrastructure.Tests\OrderRepositoryTests.cs"

)

echo ============================================================
echo === CREANDO DOCUMENTACION ===
echo ============================================================

(
echo # %projectName%
echo.
echo ## Arquitectura DDD + CQRS + Event Sourcing
echo.
echo ### Modo: %cqrsMode%
echo ### Query Engine: %useDapper%
echo.
echo ## Estructura del Proyecto
echo.
echo - Domain: Entidades, Value Objects, Domain Events, Specifications
echo - Application: Commands, Queries, DTOs, Handlers, Validators, Projections
echo - Infrastructure: Repositories, DbContexts, Event Store, Services
echo - %uiProject%: Controllers y Presentation Layer
echo.
echo ## Comandos Utiles
echo.
echo ```bash
echo # Crear migraciones
echo dotnet ef migrations add InitialCreate --project src/%projectName%.Infrastructure --startup-project src/%projectName%.%uiProject%
echo.
echo # Aplicar migraciones
echo dotnet ef database update --project src/%projectName%.Infrastructure --startup-project src/%projectName%.%uiProject%
echo.
echo # Ejecutar aplicacion
echo dotnet run --project src/%projectName%.%uiProject%
echo ```
echo.
echo ## Patrones Implementados
echo.
echo - Domain-Driven Design ^(DDD^)
echo - CQRS ^(Command Query Responsibility Segregation^)
echo - Event Sourcing
echo - Repository Pattern
echo - Unit of Work
echo - Specification Pattern
echo - MediatR Pipeline Behaviors ^(Validation + Logging^)
echo - FluentValidation
echo - AutoMapper
echo - Exception Middleware
echo.
echo ## Mejoras Incluidas
echo.
echo - **ExceptionMiddleware**: Manejo centralizado de excepciones con respuestas HTTP apropiadas
echo - **LoggingBehavior**: Pipeline de MediatR que registra automaticamente comandos y queries con tiempos de ejecucion
echo - **Docker Compose**: Configuracion lista para SQL Server containerizado
) > "%projectDirectory%\docs\README.md"

echo.
echo ============================================================
echo.
echo [SUCCESS] Proyecto %projectName% creado exitosamente!
echo.
echo Modo CQRS: %cqrsMode%
echo Query Engine: %useDapper%
echo.
echo Mejoras incluidas:
echo   [+] ExceptionMiddleware para manejo centralizado de errores
echo   [+] LoggingBehavior para registro automatico de comandos/queries
echo   [+] Docker Compose con SQL Server
echo.
echo Siguiente paso: Crear migraciones con Entity Framework Core
echo.
echo Comando:
echo cd src\%projectName%.Infrastructure
echo dotnet ef migrations add InitialCreate --startup-project ..\%projectName%.%uiProject%
echo.
echo ============================================================
pause
