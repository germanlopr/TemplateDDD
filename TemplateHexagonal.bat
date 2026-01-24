@echo off
chcp 65001 > nul
cls
color 30
echo ============================================================
echo =                                                          =
echo =     ARQUITECTURA HEXAGONAL (Ports ^& Adapters)          =
echo =           Enhanced Edition - PURE DOMAIN                =
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
echo === Creando estructura de directorios ===
mkdir "%projectDirectory%"
mkdir "%projectDirectory%\src"
mkdir "%projectDirectory%\tests"
mkdir "%projectDirectory%\docs"

cd "%projectDirectory%\src"
dotnet new sln --name %projectName%

echo.
echo ============================================================
echo === CREANDO PROYECTOS CORE (HEXAGONAL) ===
echo ============================================================

REM Core Domain (Centro del Hexágono)
dotnet new classlib -o "%projectName%.Domain"
dotnet sln add "%projectName%.Domain"

REM Application (Casos de Uso - Puerto Primario)
dotnet new classlib -o "%projectName%.Application"
dotnet sln add "%projectName%.Application"

REM Infrastructure (Adaptadores Secundarios)
dotnet new classlib -o "%projectName%.Infrastructure"
dotnet sln add "%projectName%.Infrastructure"

echo.
echo === Creando capa de Presentacion (Adaptador Primario) ===
echo 1. Web API (Recomendado)
echo 2. MVC
echo 3. Blazor Server
set /p uiType="Seleccione (1-3): "

if "%uiType%" == "1" (
    dotnet new webapi -o "%projectName%.API"
    dotnet sln add "%projectName%.API"
    set uiProject=API
) else if "%uiType%" == "2" (
    dotnet new mvc -o "%projectName%.Web"
    dotnet sln add "%projectName%.Web"
    set uiProject=Web
) else if "%uiType%" == "3" (
    dotnet new blazorserver -o "%projectName%.Web"
    dotnet sln add "%projectName%.Web"
    set uiProject=Web
) else (
    dotnet new webapi -o "%projectName%.API"
    dotnet sln add "%projectName%.API"
    set uiProject=API
)

echo.
echo === Instalando paquetes NuGet ===

REM Application packages
cd "%projectName%.Application"
dotnet add package MediatR
dotnet add package FluentValidation
dotnet restore

REM Infrastructure packages
cd "..\%projectName%.Infrastructure"
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
dotnet add package Microsoft.EntityFrameworkCore.Design
dotnet add package Newtonsoft.Json
dotnet restore

REM UI packages
cd "..\%projectName%.%uiProject%"
dotnet add package MediatR
dotnet add package Swashbuckle.AspNetCore
dotnet restore

cd ..

echo.
echo ============================================================
echo === CREANDO DOMAIN LAYER (NUCLEO DEL HEXAGONO - 100%% PURO) ===
echo ============================================================

REM Estructura de carpetas del Domain
mkdir "%projectName%.Domain\Entities"
mkdir "%projectName%.Domain\ValueObjects"
mkdir "%projectName%.Domain\Aggregates"
mkdir "%projectName%.Domain\DomainEvents"
mkdir "%projectName%.Domain\Specifications"
mkdir "%projectName%.Domain\Exceptions"
mkdir "%projectName%.Domain\Services"
mkdir "%projectName%.Domain\Common"

echo.
echo [INFO] Creando bloques de construccion del Domain...

REM ========== BASE CLASSES ==========

(
echo namespace %projectName%.Domain.Common;
echo.
echo /// ^<summary^>
echo /// Clase base para todas las entidades del dominio
echo /// ^</summary^>
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
echo.
echo     protected void MarkAsModified^(^) =^> UpdatedAt = DateTime.UtcNow;
echo }
) > "%projectName%.Domain\Common\Entity.cs"

(
echo namespace %projectName%.Domain.Common;
echo.
echo /// ^<summary^>
echo /// Raíz de agregado - punto de entrada para modificaciones
echo /// ^</summary^>
echo public abstract class AggregateRoot^<TId^> : Entity^<TId^> where TId : class
echo {
echo     public int Version { get; protected set; }
echo     
echo     protected void IncrementVersion^(^) 
echo     {
echo         Version++;
echo         MarkAsModified^(^);
echo     }
echo }
) > "%projectName%.Domain\Common\AggregateRoot.cs"
(
echo namespace %projectName%.Domain.Common;
echo.
echo /// ^<summary^>
echo /// Clase base para Value Objects ^(objetos inmutables^)
echo /// ^</summary^>
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
echo         GetEqualityComponents^(^)
echo             .Select^(x =^> x?.GetHashCode^(^) ?? 0^)
echo             .Aggregate^(^(x, y^) =^> x ^^^ y^);
echo.
echo     public static bool operator ==^(ValueObject? left, ValueObject? right^)
echo     {
echo         if ^(left is null ^^^&^^^& right is null^) return true;
echo         if ^(left is null ^|^| right is null^) return false;
echo         return left.Equals^(right^);
echo     }
echo.
echo     public static bool operator !=^(ValueObject? left, ValueObject? right^) =^> !^(left == right^);
echo }
) > "%projectName%.Domain\Common\ValueObject.cs"

REM ========== DOMAIN EVENTS ==========

(
echo namespace %projectName%.Domain.Common;
echo.
echo /// ^<summary^>
echo /// Interfaz para eventos de dominio
echo /// ^</summary^>
echo public interface IDomainEvent
echo {
echo     DateTime OccurredOn { get; }
echo     Guid EventId { get; }
echo }
echo.
echo /// ^<summary^>
echo /// Clase base para eventos de dominio
echo /// ^</summary^>
echo public abstract class DomainEvent : IDomainEvent
echo {
echo     public DateTime OccurredOn { get; } = DateTime.UtcNow;
echo     public Guid EventId { get; } = Guid.NewGuid^(^);
echo }
) > "%projectName%.Domain\Common\IDomainEvent.cs"

REM ========== IDENTITY VALUE OBJECTS ==========

(
echo namespace %projectName%.Domain.Common;
echo.
echo /// ^<summary^>
echo /// Value Object base para identidades tipadas
echo /// ^</summary^>
echo public abstract class Identity^<T^> : ValueObject where T : notnull
echo {
echo     public T Value { get; }
echo.
echo     protected Identity^(T value^)
echo     {
echo         if ^(value == null ^|^| value.Equals^(default^(T^)^)^)
echo             throw new ArgumentException^("Identity cannot be empty", nameof^(value^)^);
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
echo.
echo     public static implicit operator T^(Identity^<T^> identity^) =^> identity.Value;
echo }
) > "%projectName%.Domain\Common\Identity.cs"

(
echo namespace %projectName%.Domain.Common;
echo.
echo /// ^<summary^>
echo /// Identidades tipadas para las entidades del dominio
echo /// ^</summary^>
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

REM ========== DOMAIN EXCEPTIONS ==========

(
echo namespace %projectName%.Domain.Exceptions;
echo.
echo /// ^<summary^>
echo /// Excepción base del dominio
echo /// ^</summary^>
echo public class DomainException : Exception
echo {
echo     public DomainException^(^) { }
echo     public DomainException^(string message^) : base^(message^) { }
echo     public DomainException^(string message, Exception innerException^) 
echo         : base^(message, innerException^) { }
echo }
echo.
echo /// ^<summary^>
echo /// Excepción para reglas de negocio violadas
echo /// ^</summary^>
echo public class BusinessRuleException : DomainException
echo {
echo     public BusinessRuleException^(string message^) : base^(message^) { }
echo }
echo.
echo /// ^<summary^>
echo /// Excepción para entidades no encontradas
echo /// ^</summary^>
echo public class EntityNotFoundException : DomainException
echo {
echo     public EntityNotFoundException^(string entityName, object id^)
echo         : base^($"{entityName} with id '{id}' was not found"^) { }
echo }
) > "%projectName%.Domain\Exceptions\DomainExceptions.cs"

REM ========== VALUE OBJECTS ==========

(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Exceptions;
echo using System.Text.RegularExpressions;
echo.
echo namespace %projectName%.Domain.ValueObjects;
echo.
echo /// ^<summary^>
echo /// Value Object para direcciones de email
echo /// ^</summary^>
echo public sealed class Email : ValueObject
echo {
echo     public string Address { get; }
echo.
echo     private Email^(string address^)
echo     {
echo         Address = address;
echo     }
echo.
echo     public static Email Create^(string address^)
echo     {
echo         if ^(string.IsNullOrWhiteSpace^(address^)^)
echo             throw new DomainException^("Email cannot be empty"^);
echo.
echo         if ^(!IsValidEmail^(address^)^)
echo             throw new DomainException^($"Invalid email format: {address}"^);
echo.
echo         return new Email^(address.ToLowerInvariant^(^).Trim^(^)^);
echo     }
echo.
echo     private static bool IsValidEmail^(string email^) =^>
echo         Regex.IsMatch^(email, @"^^[^^@\s]+@[^^@\s]+\.[^^@\s]+$", RegexOptions.IgnoreCase^);
echo.
echo     protected override IEnumerable^<object^> GetEqualityComponents^(^)
echo     {
echo         yield return Address;
echo     }
echo.
echo     public static implicit operator string^(Email email^) =^> email.Address;
echo     public override string ToString^(^) =^> Address;
echo }
) > "%projectName%.Domain\ValueObjects\Email.cs"
(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Exceptions;
echo.
echo namespace %projectName%.Domain.ValueObjects;
echo.
echo /// ^<summary^>
echo /// Value Object para representar dinero con moneda
echo /// ^</summary^>
echo public sealed class Money : ValueObject
echo {
echo     public decimal Amount { get; }
echo     public string Currency { get; }
echo.
echo     private Money^(decimal amount, string currency^)
echo     {
echo         Amount = amount;
echo         Currency = currency;
echo     }
echo.
echo     public static Money Create^(decimal amount, string currency = "USD"^)
echo     {
echo         if ^(amount ^< 0^) 
echo             throw new DomainException^("Amount cannot be negative"^);
echo.
echo         if ^(string.IsNullOrWhiteSpace^(currency^)^) 
echo             throw new DomainException^("Currency is required"^);
echo.
echo         return new Money^(amount, currency.ToUpperInvariant^(^)^);
echo     }
echo.
echo     public static Money Zero^(string currency = "USD"^) =^> new^(0, currency^);
echo.
echo     public Money Add^(Money other^)
echo     {
echo         if ^(Currency != other.Currency^)
echo             throw new DomainException^("Cannot add different currencies"^);
echo.
echo         return new Money^(Amount + other.Amount, Currency^);
echo     }
echo.
echo     public Money Subtract^(Money other^)
echo     {
echo         if ^(Currency != other.Currency^)
echo             throw new DomainException^("Cannot subtract different currencies"^);
echo.
echo         return new Money^(Amount - other.Amount, Currency^);
echo     }
echo.
echo     public Money Multiply^(decimal factor^) 
echo     {
echo         if ^(factor ^< 0^) 
echo             throw new DomainException^("Factor cannot be negative"^);
echo.
echo         return new Money^(Amount * factor, Currency^);
echo     }
echo.
echo     protected override IEnumerable^<object^> GetEqualityComponents^(^)
echo     {
echo         yield return Amount;
echo         yield return Currency;
echo     }
echo.
echo     public override string ToString^(^) =^> string.Format^("{0:N2} {1}", Amount, Currency^);
echo }
) > "%projectName%.Domain\ValueObjects\Money.cs"
(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Exceptions;
echo.
echo namespace %projectName%.Domain.ValueObjects;
echo.
echo /// ^<summary^>
echo /// Value Object para direcciones postales
echo /// ^</summary^>
echo public sealed class Address : ValueObject
echo {
echo     public string Street { get; }
echo     public string City { get; }
echo     public string State { get; }
echo     public string ZipCode { get; }
echo     public string Country { get; }
echo.
echo     private Address^(string street, string city, string state, string zipCode, string country^)
echo     {
echo         Street = street;
echo         City = city;
echo         State = state;
echo         ZipCode = zipCode;
echo         Country = country;
echo     }
echo.
echo     public static Address Create^(string street, string city, string state, string zipCode, string country^)
echo     {
echo         if ^(string.IsNullOrWhiteSpace^(street^)^) 
echo             throw new DomainException^("Street is required"^);
echo         if ^(string.IsNullOrWhiteSpace^(city^)^) 
echo             throw new DomainException^("City is required"^);
echo         if ^(string.IsNullOrWhiteSpace^(zipCode^)^) 
echo             throw new DomainException^("ZipCode is required"^);
echo         if ^(string.IsNullOrWhiteSpace^(country^)^) 
echo             throw new DomainException^("Country is required"^);
echo.
echo         return new Address^(street.Trim^(^), city.Trim^(^), state?.Trim^(^) ?? "", zipCode.Trim^(^), country.Trim^(^)^);
echo     }
echo.
echo     protected override IEnumerable^<object^> GetEqualityComponents^(^)
echo     {
echo         yield return Street;
echo         yield return City;
echo         yield return State;
echo         yield return ZipCode;
echo         yield return Country;
echo     }
echo.
echo     public override string ToString^(^) =^> 
echo         $"{Street}, {City}, {State} {ZipCode}, {Country}";
echo }
) > "%projectName%.Domain\ValueObjects\Address.cs"

echo.
echo [OK] Domain Layer - Bloques fundamentales creados
echo.
REM ============================================================
REM === PARTE 2: ENTIDADES Y AGREGADOS DEL DOMINIO ===
REM ============================================================

echo.
echo [INFO] Creando Agregados y Entidades del Dominio...

REM ========== PRODUCTO AGGREGATE ==========

(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.DomainEvents;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Domain.Aggregates;
echo.
echo /// ^<summary^>
echo /// Agregado de Producto - Raíz del agregado
echo /// ^</summary^>
echo public sealed class Product : AggregateRoot^<ProductId^>
echo {
echo     private string _name = string.Empty;
echo     private Money _price = null!;
echo     private string _description = string.Empty;
echo     private int _stock;
echo     private bool _isActive;
echo.
echo     // Propiedades públicas de solo lectura
echo     public string Name =^> _name;
echo     public Money Price =^> _price;
echo     public string Description =^> _description;
echo     public int Stock =^> _stock;
echo     public bool IsActive =^> _isActive;
echo.
echo     // Constructor privado para EF
echo     private Product^(^) { }
echo.
echo     // Factory Method
echo     private Product^(ProductId id, string name, Money price, string description, int initialStock^)
echo     {
echo         Id = id ?? throw new ArgumentNullException^(nameof^(id^)^);
echo         
echo         SetName^(name^);
echo         SetPrice^(price^);
echo         SetDescription^(description^);
echo         SetStock^(initialStock^);
echo         
echo         _isActive = true;
echo         
echo         AddDomainEvent^(new ProductCreatedEvent^(Id, name, price.Amount^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public static Product Create^(ProductId id, string name, Money price, string description, int initialStock = 0^)
echo     {
echo         return new Product^(id, name, price, description, initialStock^);
echo     }
echo.
echo     // Métodos de negocio
echo     public void UpdatePrice^(Money newPrice^)
echo     {
echo         if ^(newPrice == null^) 
echo             throw new ArgumentNullException^(nameof^(newPrice^)^);
echo.
echo         var oldPrice = _price;
echo         _price = newPrice;
echo         
echo         AddDomainEvent^(new ProductPriceChangedEvent^(Id, oldPrice.Amount, newPrice.Amount^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void UpdateName^(string newName^)
echo     {
echo         SetName^(newName^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void UpdateDescription^(string newDescription^)
echo     {
echo         SetDescription^(newDescription^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void AddStock^(int quantity^)
echo     {
echo         if ^(quantity ^<= 0^) 
echo             throw new BusinessRuleException^("Quantity to add must be greater than zero"^);
echo.
echo         _stock += quantity;
echo         
echo         AddDomainEvent^(new StockAddedEvent^(Id, quantity, _stock^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void RemoveStock^(int quantity^)
echo     {
echo         if ^(quantity ^<= 0^) 
echo             throw new BusinessRuleException^("Quantity to remove must be greater than zero"^);
echo             
echo         if ^(_stock ^< quantity^)
echo             throw new BusinessRuleException^(
echo                 $"Insufficient stock. Available: {_stock}, Requested: {quantity}"^);
echo.
echo         _stock -= quantity;
echo         
echo         AddDomainEvent^(new StockRemovedEvent^(Id, quantity, _stock^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void Activate^(^)
echo     {
echo         if ^(_isActive^) return;
echo         
echo         _isActive = true;
echo         AddDomainEvent^(new ProductActivatedEvent^(Id^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void Deactivate^(^)
echo     {
echo         if ^(!_isActive^) return;
echo         
echo         _isActive = false;
echo         AddDomainEvent^(new ProductDeactivatedEvent^(Id^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public bool IsInStock^(^) =^> _stock ^> 0;
echo     public bool CanFulfillOrder^(int quantity^) =^> _stock ^>= quantity;
echo.
echo     // Métodos privados de validación
echo     private void SetName^(string name^)
echo     {
echo         if ^(string.IsNullOrWhiteSpace^(name^)^)
echo             throw new DomainException^("Product name cannot be empty"^);
echo             
echo         if ^(name.Length ^> 200^)
echo             throw new DomainException^("Product name cannot exceed 200 characters"^);
echo             
echo         _name = name.Trim^(^);
echo     }
echo.
echo     private void SetPrice^(Money price^)
echo     {
echo         if ^(price == null^)
echo             throw new ArgumentNullException^(nameof^(price^)^);
echo             
echo         _price = price;
echo     }
echo.
echo     private void SetDescription^(string description^)
echo     {
echo         if ^(description != null ^&^& description.Length ^> 1000^)
echo             throw new DomainException^("Description cannot exceed 1000 characters"^);
echo             
echo         _description = description?.Trim^(^) ?? string.Empty;
echo     }
echo.
echo     private void SetStock^(int stock^)
echo     {
echo         if ^(stock ^< 0^)
echo             throw new DomainException^("Stock cannot be negative"^);
echo             
echo         _stock = stock;
echo     }
echo }
) > "%projectName%.Domain\Aggregates\Product.cs"

REM ========== CUSTOMER AGGREGATE ==========

(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.DomainEvents;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Domain.Aggregates;
echo.
echo /// ^<summary^>
echo /// Agregado de Cliente
echo /// ^</summary^>
echo public sealed class Customer : AggregateRoot^<CustomerId^>
echo {
echo     private string _firstName = string.Empty;
echo     private string _lastName = string.Empty;
echo     private Email _email = null!;
echo     private bool _isActive;
echo.
echo     public string FirstName =^> _firstName;
echo     public string LastName =^> _lastName;
echo     public Email Email =^> _email;
echo     public bool IsActive =^> _isActive;
echo.
echo     // Constructor privado
echo     private Customer^(^) { }
echo.
echo     private Customer^(CustomerId id, string firstName, string lastName, Email email^)
echo     {
echo         Id = id ?? throw new ArgumentNullException^(nameof^(id^)^);
echo         
echo         SetFirstName^(firstName^);
echo         SetLastName^(lastName^);
echo         SetEmail^(email^);
echo         
echo         _isActive = true;
echo         
echo         AddDomainEvent^(new CustomerCreatedEvent^(Id, GetFullName^(^), email.Address^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public static Customer Create^(CustomerId id, string firstName, string lastName, Email email^)
echo     {
echo         return new Customer^(id, firstName, lastName, email^);
echo     }
echo.
echo     public string GetFullName^(^) =^> $"{_firstName} {_lastName}";
echo.
echo     public void UpdateEmail^(Email newEmail^)
echo     {
echo         if ^(newEmail == null^)
echo             throw new ArgumentNullException^(nameof^(newEmail^)^);
echo.
echo         var oldEmail = _email;
echo         _email = newEmail;
echo         
echo         AddDomainEvent^(new CustomerEmailChangedEvent^(Id, oldEmail.Address, newEmail.Address^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void UpdateName^(string firstName, string lastName^)
echo     {
echo         SetFirstName^(firstName^);
echo         SetLastName^(lastName^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void Activate^(^)
echo     {
echo         if ^(_isActive^) return;
echo         
echo         _isActive = true;
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void Deactivate^(^)
echo     {
echo         if ^(!_isActive^) return;
echo         
echo         _isActive = false;
echo         AddDomainEvent^(new CustomerDeactivatedEvent^(Id^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     private void SetFirstName^(string firstName^)
echo     {
echo         if ^(string.IsNullOrWhiteSpace^(firstName^)^)
echo             throw new DomainException^("First name is required"^);
echo             
echo         if ^(firstName.Length ^> 100^)
echo             throw new DomainException^("First name cannot exceed 100 characters"^);
echo             
echo         _firstName = firstName.Trim^(^);
echo     }
echo.
echo     private void SetLastName^(string lastName^)
echo     {
echo         if ^(string.IsNullOrWhiteSpace^(lastName^)^)
echo             throw new DomainException^("Last name is required"^);
echo             
echo         if ^(lastName.Length ^> 100^)
echo             throw new DomainException^("Last name cannot exceed 100 characters"^);
echo             
echo         _lastName = lastName.Trim^(^);
echo     }
echo.
echo     private void SetEmail^(Email email^)
echo     {
echo         _email = email ?? throw new ArgumentNullException^(nameof^(email^)^);
echo     }
echo }
) > "%projectName%.Domain\Aggregates\Customer.cs"

REM ========== ORDER AGGREGATE ==========

(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.DomainEvents;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Domain.Aggregates;
echo.
echo /// ^<summary^>
echo /// Agregado de Orden - Gestiona items de orden
echo /// ^</summary^>
echo public sealed class Order : AggregateRoot^<OrderId^>
echo {
echo     private readonly List^<OrderItem^> _items = new^(^);
echo     private CustomerId _customerId = null!;
echo     private DateTime _orderDate;
echo     private OrderStatus _status;
echo.
echo     public CustomerId CustomerId =^> _customerId;
echo     public DateTime OrderDate =^> _orderDate;
echo     public OrderStatus Status =^> _status;
echo     public IReadOnlyCollection^<OrderItem^> Items =^> _items.AsReadOnly^(^);
echo.
echo     // Constructor privado
echo     private Order^(^) { }
echo.
echo     private Order^(OrderId id, CustomerId customerId^)
echo     {
echo         Id = id ?? throw new ArgumentNullException^(nameof^(id^)^);
echo         _customerId = customerId ?? throw new ArgumentNullException^(nameof^(customerId^)^);
echo         
echo         _orderDate = DateTime.UtcNow;
echo         _status = OrderStatus.Pending;
echo         
echo         AddDomainEvent^(new OrderCreatedEvent^(Id, customerId^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public static Order Create^(OrderId id, CustomerId customerId^)
echo     {
echo         return new Order^(id, customerId^);
echo     }
echo.
echo     public void AddItem^(ProductId productId, Money unitPrice, int quantity^)
echo     {
echo         if ^(_status != OrderStatus.Pending^)
echo             throw new BusinessRuleException^("Cannot add items to a non-pending order"^);
echo.
echo         var existingItem = _items.FirstOrDefault^(i =^> i.ProductId.Equals^(productId^)^);
echo         
echo         if ^(existingItem != null^)
echo         {
echo             existingItem.UpdateQuantity^(existingItem.Quantity + quantity^);
echo         }
echo         else
echo         {
echo             var newItem = OrderItem.Create^(OrderItemId.Create^(^), productId, unitPrice, quantity^);
echo             _items.Add^(newItem^);
echo         }
echo         
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void RemoveItem^(ProductId productId^)
echo     {
echo         if ^(_status != OrderStatus.Pending^)
echo             throw new BusinessRuleException^("Cannot remove items from a non-pending order"^);
echo.
echo         var item = _items.FirstOrDefault^(i =^> i.ProductId.Equals^(productId^)^);
echo         if ^(item == null^)
echo             throw new BusinessRuleException^("Item not found in order"^);
echo.
echo         _items.Remove^(item^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public Money CalculateTotal^(^)
echo     {
echo         if ^(!_items.Any^(^)^) 
echo             return Money.Zero^(^);
echo.
echo         return _items
echo             .Select^(i =^> i.GetSubtotal^(^)^)
echo             .Aggregate^(^(a, b^) =^> a.Add^(b^)^);
echo     }
echo.
echo     public void Confirm^(^)
echo     {
echo         if ^(_status != OrderStatus.Pending^)
echo             throw new BusinessRuleException^("Only pending orders can be confirmed"^);
echo             
echo         if ^(!_items.Any^(^)^)
echo             throw new BusinessRuleException^("Cannot confirm an empty order"^);
echo.
echo         _status = OrderStatus.Confirmed;
echo         
echo         AddDomainEvent^(new OrderConfirmedEvent^(Id, CalculateTotal^(^).Amount^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void Ship^(^)
echo     {
echo         if ^(_status != OrderStatus.Confirmed^)
echo             throw new BusinessRuleException^("Only confirmed orders can be shipped"^);
echo.
echo         _status = OrderStatus.Shipped;
echo         AddDomainEvent^(new OrderShippedEvent^(Id^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void Deliver^(^)
echo     {
echo         if ^(_status != OrderStatus.Shipped^)
echo             throw new BusinessRuleException^("Only shipped orders can be delivered"^);
echo.
echo         _status = OrderStatus.Delivered;
echo         AddDomainEvent^(new OrderDeliveredEvent^(Id^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public void Cancel^(^)
echo     {
echo         if ^(_status == OrderStatus.Delivered^)
echo             throw new BusinessRuleException^("Cannot cancel a delivered order"^);
echo.
echo         _status = OrderStatus.Cancelled;
echo         AddDomainEvent^(new OrderCancelledEvent^(Id^)^);
echo         IncrementVersion^(^);
echo     }
echo.
echo     public int GetItemCount^(^) =^> _items.Count;
echo     public bool IsEmpty^(^) =^> !_items.Any^(^);
echo }
echo.
echo public enum OrderStatus
echo {
echo     Pending = 0,
echo     Confirmed = 1,
echo     Shipped = 2,
echo     Delivered = 3,
echo     Cancelled = 4
echo }
) > "%projectName%.Domain\Aggregates\Order.cs"

REM ========== ORDER ITEM ENTITY ==========

(
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Domain.Entities;
echo.
echo /// ^<summary^>
echo /// Entidad OrderItem - Parte del agregado Order
echo /// ^</summary^>
echo public sealed class OrderItem : Entity^<OrderItemId^>
echo {
echo     private ProductId _productId = null!;
echo     private Money _unitPrice = null!;
echo     private int _quantity;
echo.
echo     public ProductId ProductId =^> _productId;
echo     public Money UnitPrice =^> _unitPrice;
echo     public int Quantity =^> _quantity;
echo.
echo     // Constructor privado
echo     private OrderItem^(^) { }
echo.
echo     private OrderItem^(OrderItemId id, ProductId productId, Money unitPrice, int quantity^)
echo     {
echo         Id = id ?? throw new ArgumentNullException^(nameof^(id^)^);
echo         _productId = productId ?? throw new ArgumentNullException^(nameof^(productId^)^);
echo         
echo         SetUnitPrice^(unitPrice^);
echo         SetQuantity^(quantity^);
echo     }
echo.
echo     public static OrderItem Create^(OrderItemId id, ProductId productId, Money unitPrice, int quantity^)
echo     {
echo         return new OrderItem^(id, productId, unitPrice, quantity^);
echo     }
echo.
echo     public void UpdateQuantity^(int newQuantity^)
echo     {
echo         SetQuantity^(newQuantity^);
echo         MarkAsModified^(^);
echo     }
echo.
echo     public void UpdateUnitPrice^(Money newPrice^)
echo     {
echo         SetUnitPrice^(newPrice^);
echo         MarkAsModified^(^);
echo     }
echo.
echo     public Money GetSubtotal^(^) =^> _unitPrice.Multiply^(_quantity^);
echo.
echo     private void SetQuantity^(int quantity^)
echo     {
echo         if ^(quantity ^<= 0^)
echo             throw new DomainException^("Quantity must be greater than zero"^);
echo             
echo         _quantity = quantity;
echo     }
echo.
echo     private void SetUnitPrice^(Money price^)
echo     {
echo         _unitPrice = price ?? throw new ArgumentNullException^(nameof^(price^)^);
echo     }
echo }
) > "%projectName%.Domain\Entities\OrderItem.cs"

echo.
echo [OK] Agregados y Entidades creados
echo.
REM ============================================================
REM === PARTE 3: DOMAIN EVENTS, SPECIFICATIONS Y SERVICES ===
REM ============================================================

echo.
echo [INFO] Creando Domain Events...

REM ========== DOMAIN EVENTS ==========

(
echo using %projectName%.Domain.Common;
echo.
echo namespace %projectName%.Domain.DomainEvents;
echo.
echo // ========== PRODUCT EVENTS ==========
echo.
echo public sealed class ProductCreatedEvent : DomainEvent
echo {
echo     public ProductId ProductId { get; }
echo     public string ProductName { get; }
echo     public decimal Price { get; }
echo.
echo     public ProductCreatedEvent^(ProductId productId, string productName, decimal price^)
echo     {
echo         ProductId = productId;
echo         ProductName = productName;
echo         Price = price;
echo     }
echo }
echo.
echo public sealed class ProductPriceChangedEvent : DomainEvent
echo {
echo     public ProductId ProductId { get; }
echo     public decimal OldPrice { get; }
echo     public decimal NewPrice { get; }
echo.
echo     public ProductPriceChangedEvent^(ProductId productId, decimal oldPrice, decimal newPrice^)
echo     {
echo         ProductId = productId;
echo         OldPrice = oldPrice;
echo         NewPrice = newPrice;
echo     }
echo }
echo.
echo public sealed class StockAddedEvent : DomainEvent
echo {
echo     public ProductId ProductId { get; }
echo     public int QuantityAdded { get; }
echo     public int NewStock { get; }
echo.
echo     public StockAddedEvent^(ProductId productId, int quantityAdded, int newStock^)
echo     {
echo         ProductId = productId;
echo         QuantityAdded = quantityAdded;
echo         NewStock = newStock;
echo     }
echo }
echo.
echo public sealed class StockRemovedEvent : DomainEvent
echo {
echo     public ProductId ProductId { get; }
echo     public int QuantityRemoved { get; }
echo     public int NewStock { get; }
echo.
echo     public StockRemovedEvent^(ProductId productId, int quantityRemoved, int newStock^)
echo     {
echo         ProductId = productId;
echo         QuantityRemoved = quantityRemoved;
echo         NewStock = newStock;
echo     }
echo }
echo.
echo public sealed class ProductActivatedEvent : DomainEvent
echo {
echo     public ProductId ProductId { get; }
echo.
echo     public ProductActivatedEvent^(ProductId productId^)
echo     {
echo         ProductId = productId;
echo     }
echo }
echo.
echo public sealed class ProductDeactivatedEvent : DomainEvent
echo {
echo     public ProductId ProductId { get; }
echo.
echo     public ProductDeactivatedEvent^(ProductId productId^)
echo     {
echo         ProductId = productId;
echo     }
echo }
) > "%projectName%.Domain\DomainEvents\ProductEvents.cs"

(
echo using %projectName%.Domain.Common;
echo.
echo namespace %projectName%.Domain.DomainEvents;
echo.
echo // ========== CUSTOMER EVENTS ==========
echo.
echo public sealed class CustomerCreatedEvent : DomainEvent
echo {
echo     public CustomerId CustomerId { get; }
echo     public string FullName { get; }
echo     public string Email { get; }
echo.
echo     public CustomerCreatedEvent^(CustomerId customerId, string fullName, string email^)
echo     {
echo         CustomerId = customerId;
echo         FullName = fullName;
echo         Email = email;
echo     }
echo }
echo.
echo public sealed class CustomerEmailChangedEvent : DomainEvent
echo {
echo     public CustomerId CustomerId { get; }
echo     public string OldEmail { get; }
echo     public string NewEmail { get; }
echo.
echo     public CustomerEmailChangedEvent^(CustomerId customerId, string oldEmail, string newEmail^)
echo     {
echo         CustomerId = customerId;
echo         OldEmail = oldEmail;
echo         NewEmail = newEmail;
echo     }
echo }
echo.
echo public sealed class CustomerDeactivatedEvent : DomainEvent
echo {
echo     public CustomerId CustomerId { get; }
echo.
echo     public CustomerDeactivatedEvent^(CustomerId customerId^)
echo     {
echo         CustomerId = customerId;
echo     }
echo }
) > "%projectName%.Domain\DomainEvents\CustomerEvents.cs"

(
echo using %projectName%.Domain.Common;
echo.
echo namespace %projectName%.Domain.DomainEvents;
echo.
echo // ========== ORDER EVENTS ==========
echo.
echo public sealed class OrderCreatedEvent : DomainEvent
echo {
echo     public OrderId OrderId { get; }
echo     public CustomerId CustomerId { get; }
echo.
echo     public OrderCreatedEvent^(OrderId orderId, CustomerId customerId^)
echo     {
echo         OrderId = orderId;
echo         CustomerId = customerId;
echo     }
echo }
echo.
echo public sealed class OrderConfirmedEvent : DomainEvent
echo {
echo     public OrderId OrderId { get; }
echo     public decimal TotalAmount { get; }
echo.
echo     public OrderConfirmedEvent^(OrderId orderId, decimal totalAmount^)
echo     {
echo         OrderId = orderId;
echo         TotalAmount = totalAmount;
echo     }
echo }
echo.
echo public sealed class OrderShippedEvent : DomainEvent
echo {
echo     public OrderId OrderId { get; }
echo.
echo     public OrderShippedEvent^(OrderId orderId^)
echo     {
echo         OrderId = orderId;
echo     }
echo }
echo.
echo public sealed class OrderDeliveredEvent : DomainEvent
echo {
echo     public OrderId OrderId { get; }
echo.
echo     public OrderDeliveredEvent^(OrderId orderId^)
echo     {
echo         OrderId = orderId;
echo     }
echo }
echo.
echo public sealed class OrderCancelledEvent : DomainEvent
echo {
echo     public OrderId OrderId { get; }
echo.
echo     public OrderCancelledEvent^(OrderId orderId^)
echo     {
echo         OrderId = orderId;
echo     }
echo }
) > "%projectName%.Domain\DomainEvents\OrderEvents.cs"

echo.
echo [INFO] Creando Specifications (Patron Specification)...

REM ========== SPECIFICATIONS ==========

(
echo using System.Linq.Expressions;
echo.
echo namespace %projectName%.Domain.Specifications;
echo.
echo /// ^<summary^>
echo /// Interfaz base para especificaciones
echo /// ^</summary^>
echo public interface ISpecification^<T^>
echo {
echo     Expression^<Func^<T, bool^>^> ToExpression^(^);
echo     bool IsSatisfiedBy^(T entity^);
echo }
echo.
echo /// ^<summary^>
echo /// Clase base abstracta para especificaciones
echo /// ^</summary^>
echo public abstract class Specification^<T^> : ISpecification^<T^>
echo {
echo     public abstract Expression^<Func^<T, bool^>^> ToExpression^(^);
echo.
echo     public bool IsSatisfiedBy^(T entity^)
echo     {
echo         var predicate = ToExpression^(^).Compile^(^);
echo         return predicate^(entity^);
echo     }
echo.
echo     // Operadores lógicos
echo     public Specification^<T^> And^(Specification^<T^> specification^)
echo     {
echo         return new AndSpecification^<T^>^(this, specification^);
echo     }
echo.
echo     public Specification^<T^> Or^(Specification^<T^> specification^)
echo     {
echo         return new OrSpecification^<T^>^(this, specification^);
echo     }
echo.
echo     public Specification^<T^> Not^(^)
echo     {
echo         return new NotSpecification^<T^>^(this^);
echo     }
echo }
echo.
echo // Especificaciones combinadas
echo internal class AndSpecification^<T^> : Specification^<T^>
echo {
echo     private readonly Specification^<T^> _left;
echo     private readonly Specification^<T^> _right;
echo.
echo     public AndSpecification^(Specification^<T^> left, Specification^<T^> right^)
echo     {
echo         _left = left;
echo         _right = right;
echo     }
echo.
echo     public override Expression^<Func^<T, bool^>^> ToExpression^(^)
echo     {
echo         var leftExpression = _left.ToExpression^(^);
echo         var rightExpression = _right.ToExpression^(^);
echo         var parameter = Expression.Parameter^(typeof^(T^)^);
echo.
echo         var combined = Expression.AndAlso^(
echo             Expression.Invoke^(leftExpression, parameter^),
echo             Expression.Invoke^(rightExpression, parameter^)^);
echo.
echo         return Expression.Lambda^<Func^<T, bool^>^>^(combined, parameter^);
echo     }
echo }
echo.
echo internal class OrSpecification^<T^> : Specification^<T^>
echo {
echo     private readonly Specification^<T^> _left;
echo     private readonly Specification^<T^> _right;
echo.
echo     public OrSpecification^(Specification^<T^> left, Specification^<T^> right^)
echo     {
echo         _left = left;
echo         _right = right;
echo     }
echo.
echo     public override Expression^<Func^<T, bool^>^> ToExpression^(^)
echo     {
echo         var leftExpression = _left.ToExpression^(^);
echo         var rightExpression = _right.ToExpression^(^);
echo         var parameter = Expression.Parameter^(typeof^(T^)^);
echo.
echo         var combined = Expression.OrElse^(
echo             Expression.Invoke^(leftExpression, parameter^),
echo             Expression.Invoke^(rightExpression, parameter^)^);
echo.
echo         return Expression.Lambda^<Func^<T, bool^>^>^(combined, parameter^);
echo     }
echo }
echo.
echo internal class NotSpecification^<T^> : Specification^<T^>
echo {
echo     private readonly Specification^<T^> _specification;
echo.
echo     public NotSpecification^(Specification^<T^> specification^)
echo     {
echo         _specification = specification;
echo     }
echo.
echo     public override Expression^<Func^<T, bool^>^> ToExpression^(^)
echo     {
echo         var expression = _specification.ToExpression^(^);
echo         var parameter = Expression.Parameter^(typeof^(T^)^);
echo.
echo         var notExpression = Expression.Not^(Expression.Invoke^(expression, parameter^)^);
echo         return Expression.Lambda^<Func^<T, bool^>^>^(notExpression, parameter^);
echo     }
echo }
) > "%projectName%.Domain\Specifications\Specification.cs"

(
echo using %projectName%.Domain.Aggregates;
echo using System.Linq.Expressions;
echo.
echo namespace %projectName%.Domain.Specifications;
echo.
echo /// ^<summary^>
echo /// Especificaciones para Product
echo /// ^</summary^>
echo public class ActiveProductsSpecification : Specification^<Product^>
echo {
echo     public override Expression^<Func^<Product, bool^>^> ToExpression^(^)
echo     {
echo         return product =^> product.IsActive;
echo     }
echo }
echo.
echo public class ProductsInStockSpecification : Specification^<Product^>
echo {
echo     public override Expression^<Func^<Product, bool^>^> ToExpression^(^)
echo     {
echo         return product =^> product.Stock ^> 0;
echo     }
echo }
echo.
echo public class ProductsByPriceRangeSpecification : Specification^<Product^>
echo {
echo     private readonly decimal _minPrice;
echo     private readonly decimal _maxPrice;
echo.
echo     public ProductsByPriceRangeSpecification^(decimal minPrice, decimal maxPrice^)
echo     {
echo         _minPrice = minPrice;
echo         _maxPrice = maxPrice;
echo     }
echo.
echo     public override Expression^<Func^<Product, bool^>^> ToExpression^(^)
echo     {
echo         return product =^> 
echo             product.Price.Amount ^>= _minPrice ^&^& 
echo             product.Price.Amount ^<= _maxPrice;
echo     }
echo }
echo.
echo public class ProductByNameSpecification : Specification^<Product^>
echo {
echo     private readonly string _name;
echo.
echo     public ProductByNameSpecification^(string name^)
echo     {
echo         _name = name?.ToLowerInvariant^(^) ?? string.Empty;
echo     }
echo.
echo     public override Expression^<Func^<Product, bool^>^> ToExpression^(^)
echo     {
echo         return product =^> product.Name.ToLower^(^).Contains^(_name^);
echo     }
echo }
echo.
echo public class LowStockProductsSpecification : Specification^<Product^>
echo {
echo     private readonly int _threshold;
echo.
echo     public LowStockProductsSpecification^(int threshold = 10^)
echo     {
echo         _threshold = threshold;
echo     }
echo.
echo     public override Expression^<Func^<Product, bool^>^> ToExpression^(^)
echo     {
echo         return product =^> product.Stock ^< _threshold ^&^& product.Stock ^> 0;
echo     }
echo }
) > "%projectName%.Domain\Specifications\ProductSpecifications.cs"

(
echo using %projectName%.Domain.Aggregates;
echo using System.Linq.Expressions;
echo.
echo namespace %projectName%.Domain.Specifications;
echo.
echo /// ^<summary^>
echo /// Especificaciones para Customer
echo /// ^</summary^>
echo public class ActiveCustomersSpecification : Specification^<Customer^>
echo {
echo     public override Expression^<Func^<Customer, bool^>^> ToExpression^(^)
echo     {
echo         return customer =^> customer.IsActive;
echo     }
echo }
echo.
echo public class CustomerByEmailSpecification : Specification^<Customer^>
echo {
echo     private readonly string _email;
echo.
echo     public CustomerByEmailSpecification^(string email^)
echo     {
echo         _email = email?.ToLowerInvariant^(^) ?? string.Empty;
echo     }
echo.
echo     public override Expression^<Func^<Customer, bool^>^> ToExpression^(^)
echo     {
echo         return customer =^> customer.Email.Address.ToLower^(^) == _email;
echo     }
echo }
) > "%projectName%.Domain\Specifications\CustomerSpecifications.cs"

(
echo using %projectName%.Domain.Aggregates;
echo using System.Linq.Expressions;
echo.
echo namespace %projectName%.Domain.Specifications;
echo.
echo /// ^<summary^>
echo /// Especificaciones para Order
echo /// ^</summary^>
echo public class OrdersByCustomerSpecification : Specification^<Order^>
echo {
echo     private readonly CustomerId _customerId;
echo.
echo     public OrdersByCustomerSpecification^(CustomerId customerId^)
echo     {
echo         _customerId = customerId;
echo     }
echo.
echo     public override Expression^<Func^<Order, bool^>^> ToExpression^(^)
echo     {
echo         return order =^> order.CustomerId.Equals^(_customerId^);
echo     }
echo }
echo.
echo public class OrdersByStatusSpecification : Specification^<Order^>
echo {
echo     private readonly OrderStatus _status;
echo.
echo     public OrdersByStatusSpecification^(OrderStatus status^)
echo     {
echo         _status = status;
echo     }
echo.
echo     public override Expression^<Func^<Order, bool^>^> ToExpression^(^)
echo     {
echo         return order =^> order.Status == _status;
echo     }
echo }
echo.
echo public class PendingOrdersSpecification : Specification^<Order^>
echo {
echo     public override Expression^<Func^<Order, bool^>^> ToExpression^(^)
echo     {
echo         return order =^> order.Status == OrderStatus.Pending;
echo     }
echo }
echo.
echo public class OrdersByDateRangeSpecification : Specification^<Order^>
echo {
echo     private readonly DateTime _startDate;
echo     private readonly DateTime _endDate;
echo.
echo     public OrdersByDateRangeSpecification^(DateTime startDate, DateTime endDate^)
echo     {
echo         _startDate = startDate;
echo         _endDate = endDate;
echo     }
echo.
echo     public override Expression^<Func^<Order, bool^>^> ToExpression^(^)
echo     {
echo         return order =^> 
echo             order.OrderDate ^>= _startDate ^&^& 
echo             order.OrderDate ^<= _endDate;
echo     }
echo }
) > "%projectName%.Domain\Specifications\OrderSpecifications.cs"

echo.
echo [INFO] Creando Domain Services...

REM ========== DOMAIN SERVICES ==========

(
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Domain.Services;
echo.
echo /// ^<summary^>
echo /// Servicio de dominio para gestión de precios
echo /// ^</summary^>
echo public class PricingService
echo {
echo     public Money CalculateDiscount^(Money originalPrice, decimal discountPercentage^)
echo     {
echo         if ^(discountPercentage ^< 0 ^|^| discountPercentage ^> 100^)
echo             throw new DomainException^("Discount percentage must be between 0 and 100"^);
echo.
echo         var discountAmount = originalPrice.Amount * ^(discountPercentage / 100m^);
echo         var finalAmount = originalPrice.Amount - discountAmount;
echo.
echo         return Money.Create^(finalAmount, originalPrice.Currency^);
echo     }
echo.
echo     public Money ApplyTax^(Money price, decimal taxRate^)
echo     {
echo         if ^(taxRate ^< 0^)
echo             throw new DomainException^("Tax rate cannot be negative"^);
echo.
echo         var taxAmount = price.Amount * ^(taxRate / 100m^);
echo         var finalAmount = price.Amount + taxAmount;
echo.
echo         return Money.Create^(finalAmount, price.Currency^);
echo     }
echo.
echo     public bool IsPriceValid^(Money price, Money minimumPrice^)
echo     {
echo         if ^(price.Currency != minimumPrice.Currency^)
echo             throw new DomainException^("Cannot compare prices in different currencies"^);
echo.
echo         return price.Amount ^>= minimumPrice.Amount;
echo     }
echo }
) > "%projectName%.Domain\Services\PricingService.cs"

(
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Exceptions;
echo.
echo namespace %projectName%.Domain.Services;
echo.
echo /// ^<summary^>
echo /// Servicio de dominio para validación de órdenes
echo /// ^</summary^>
echo public class OrderValidationService
echo {
echo     public bool CanConfirmOrder^(Order order^)
echo     {
echo         if ^(order == null^)
echo             throw new ArgumentNullException^(nameof^(order^)^);
echo.
echo         return order.Status == OrderStatus.Pending ^&^& !order.IsEmpty^(^);
echo     }
echo.
echo     public bool CanCancelOrder^(Order order^)
echo     {
echo         if ^(order == null^)
echo             throw new ArgumentNullException^(nameof^(order^)^);
echo.
echo         return order.Status != OrderStatus.Delivered;
echo     }
echo.
echo     public void ValidateOrderForShipping^(Order order^)
echo     {
echo         if ^(order == null^)
echo             throw new ArgumentNullException^(nameof^(order^)^);
echo.
echo         if ^(order.Status != OrderStatus.Confirmed^)
echo             throw new BusinessRuleException^("Only confirmed orders can be shipped"^);
echo.
echo         if ^(order.IsEmpty^(^)^)
echo             throw new BusinessRuleException^("Cannot ship an empty order"^);
echo     }
echo }
) > "%projectName%.Domain\Services\OrderValidationService.cs"

(
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Exceptions;
echo.
echo namespace %projectName%.Domain.Services;
echo.
echo /// ^<summary^>
echo /// Servicio de dominio para gestión de inventario
echo /// ^</summary^>
echo public class InventoryService
echo {
echo     public bool IsStockAvailable^(Product product, int requiredQuantity^)
echo     {
echo         if ^(product == null^)
echo             throw new ArgumentNullException^(nameof^(product^)^);
echo.
echo         if ^(requiredQuantity ^<= 0^)
echo             throw new DomainException^("Required quantity must be greater than zero"^);
echo.
echo         return product.CanFulfillOrder^(requiredQuantity^);
echo     }
echo.
echo     public void ReserveStock^(Product product, int quantity^)
echo     {
echo         if ^(product == null^)
echo             throw new ArgumentNullException^(nameof^(product^)^);
echo.
echo         if ^(!product.IsActive^)
echo             throw new BusinessRuleException^("Cannot reserve stock for inactive products"^);
echo.
echo         if ^(!IsStockAvailable^(product, quantity^)^)
echo             throw new BusinessRuleException^(
echo                 $"Insufficient stock. Available: {product.Stock}, Required: {quantity}"^);
echo.
echo         product.RemoveStock^(quantity^);
echo     }
echo.
echo     public void RestoreStock^(Product product, int quantity^)
echo     {
echo         if ^(product == null^)
echo             throw new ArgumentNullException^(nameof^(product^)^);
echo.
echo         product.AddStock^(quantity^);
echo     }
echo.
echo     public bool RequiresReorder^(Product product, int reorderThreshold^)
echo     {
echo         if ^(product == null^)
echo             throw new ArgumentNullException^(nameof^(product^)^);
echo.
echo         return product.Stock ^< reorderThreshold;
echo     }
echo }
) > "%projectName%.Domain\Services\InventoryService.cs"

echo.
echo [SUCCESS] Domain Layer completado!
echo.
echo Componentes creados:
echo   [+] Entities ^& Aggregates (Product, Customer, Order, OrderItem)
echo   [+] Value Objects (Email, Money, Address)
echo   [+] Domain Events (Product, Customer, Order events)
echo   [+] Specifications (Pattern con combinadores AND/OR/NOT)
echo   [+] Domain Services (Pricing, OrderValidation, Inventory)
echo   [+] Domain Exceptions
echo.
REM ============================================================
REM === PARTE 4: APPLICATION LAYER (PORTS ^& USE CASES) ===
REM ============================================================

echo.
echo ============================================================
echo === CREANDO APPLICATION LAYER (HEXAGONAL ARCHITECTURE) ===
echo ============================================================

REM Estructura de carpetas Application
mkdir "%projectName%.Application\Ports"
mkdir "%projectName%.Application\Ports\Input"
mkdir "%projectName%.Application\Ports\Output"
mkdir "%projectName%.Application\UseCases"
mkdir "%projectName%.Application\UseCases\Products"
mkdir "%projectName%.Application\UseCases\Customers"
mkdir "%projectName%.Application\UseCases\Orders"
mkdir "%projectName%.Application\DTOs"
mkdir "%projectName%.Application\DTOs\Requests"
mkdir "%projectName%.Application\DTOs\Responses"
mkdir "%projectName%.Application\Validators"
mkdir "%projectName%.Application\Behaviors"
mkdir "%projectName%.Application\Exceptions"
mkdir "%projectName%.Application\Mappings"

echo.
echo [INFO] Creando Puertos de Entrada (Input Ports - Primary)...

REM ========== INPUT PORTS (Primary Ports - Driving) ==========

(
echo using %projectName%.Application.DTOs.Requests;
echo using %projectName%.Application.DTOs.Responses;
echo.
echo namespace %projectName%.Application.Ports.Input;
echo.
echo /// ^<summary^>
echo /// Puerto de entrada para gestión de productos
echo /// ^</summary^>
echo public interface IProductService
echo {
echo     Task^<ProductResponse^> CreateProductAsync^(CreateProductRequest request, CancellationToken ct = default^);
echo     Task^<ProductResponse^> GetProductByIdAsync^(int id, CancellationToken ct = default^);
echo     Task^<IEnumerable^<ProductResponse^>^> GetAllProductsAsync^(CancellationToken ct = default^);
echo     Task^<IEnumerable^<ProductResponse^>^> GetActiveProductsAsync^(CancellationToken ct = default^);
echo     Task^<IEnumerable^<ProductResponse^>^> GetProductsInStockAsync^(CancellationToken ct = default^);
echo     Task^<IEnumerable^<ProductResponse^>^> GetProductsByPriceRangeAsync^(decimal minPrice, decimal maxPrice, CancellationToken ct = default^);
echo     Task^<bool^> UpdateProductPriceAsync^(int id, decimal newPrice, CancellationToken ct = default^);
echo     Task^<bool^> AddStockAsync^(int id, int quantity, CancellationToken ct = default^);
echo     Task^<bool^> RemoveStockAsync^(int id, int quantity, CancellationToken ct = default^);
echo     Task^<bool^> DeactivateProductAsync^(int id, CancellationToken ct = default^);
echo     Task^<bool^> ActivateProductAsync^(int id, CancellationToken ct = default^);
echo }
) > "%projectName%.Application\Ports\Input\IProductService.cs"

(
echo using %projectName%.Application.DTOs.Requests;
echo using %projectName%.Application.DTOs.Responses;
echo.
echo namespace %projectName%.Application.Ports.Input;
echo.
echo /// ^<summary^>
echo /// Puerto de entrada para gestión de clientes
echo /// ^</summary^>
echo public interface ICustomerService
echo {
echo     Task^<CustomerResponse^> CreateCustomerAsync^(CreateCustomerRequest request, CancellationToken ct = default^);
echo     Task^<CustomerResponse^> GetCustomerByIdAsync^(int id, CancellationToken ct = default^);
echo     Task^<IEnumerable^<CustomerResponse^>^> GetAllCustomersAsync^(CancellationToken ct = default^);
echo     Task^<IEnumerable^<CustomerResponse^>^> GetActiveCustomersAsync^(CancellationToken ct = default^);
echo     Task^<bool^> UpdateCustomerEmailAsync^(int id, string newEmail, CancellationToken ct = default^);
echo     Task^<bool^> DeactivateCustomerAsync^(int id, CancellationToken ct = default^);
echo }
) > "%projectName%.Application\Ports\Input\ICustomerService.cs"

(
echo using %projectName%.Application.DTOs.Requests;
echo using %projectName%.Application.DTOs.Responses;
echo.
echo namespace %projectName%.Application.Ports.Input;
echo.
echo /// ^<summary^>
echo /// Puerto de entrada para gestión de órdenes
echo /// ^</summary^>
echo public interface IOrderService
echo {
echo     Task^<OrderResponse^> CreateOrderAsync^(CreateOrderRequest request, CancellationToken ct = default^);
echo     Task^<OrderResponse^> GetOrderByIdAsync^(int id, CancellationToken ct = default^);
echo     Task^<IEnumerable^<OrderResponse^>^> GetOrdersByCustomerAsync^(int customerId, CancellationToken ct = default^);
echo     Task^<IEnumerable^<OrderResponse^>^> GetPendingOrdersAsync^(CancellationToken ct = default^);
echo     Task^<bool^> AddItemToOrderAsync^(int orderId, AddOrderItemRequest request, CancellationToken ct = default^);
echo     Task^<bool^> ConfirmOrderAsync^(int id, CancellationToken ct = default^);
echo     Task^<bool^> ShipOrderAsync^(int id, CancellationToken ct = default^);
echo     Task^<bool^> DeliverOrderAsync^(int id, CancellationToken ct = default^);
echo     Task^<bool^> CancelOrderAsync^(int id, CancellationToken ct = default^);
echo }
) > "%projectName%.Application\Ports\Input\IOrderService.cs"

echo.
echo [INFO] Creando Puertos de Salida (Output Ports - Secondary)...

REM ========== OUTPUT PORTS (Secondary Ports - Driven) ==========

(
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo.
echo namespace %projectName%.Application.Ports.Output;
echo.
echo /// ^<summary^>
echo /// Puerto de salida para repositorio de productos
echo /// ^</summary^>
echo public interface IProductRepository
echo {
echo     Task^<Product?^> GetByIdAsync^(ProductId id, CancellationToken ct = default^);
echo     Task^<IEnumerable^<Product^>^> GetAllAsync^(CancellationToken ct = default^);
echo     Task^<IEnumerable^<Product^>^> FindAsync^(ISpecification^<Product^> specification, CancellationToken ct = default^);
echo     Task^<Product^> AddAsync^(Product product, CancellationToken ct = default^);
echo     Task UpdateAsync^(Product product, CancellationToken ct = default^);
echo     Task DeleteAsync^(Product product, CancellationToken ct = default^);
echo     Task^<bool^> ExistsAsync^(ProductId id, CancellationToken ct = default^);
echo }
) > "%projectName%.Application\Ports\Output\IProductRepository.cs"

(
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo.
echo namespace %projectName%.Application.Ports.Output;
echo.
echo /// ^<summary^>
echo /// Puerto de salida para repositorio de clientes
echo /// ^</summary^>
echo public interface ICustomerRepository
echo {
echo     Task^<Customer?^> GetByIdAsync^(CustomerId id, CancellationToken ct = default^);
echo     Task^<IEnumerable^<Customer^>^> GetAllAsync^(CancellationToken ct = default^);
echo     Task^<IEnumerable^<Customer^>^> FindAsync^(ISpecification^<Customer^> specification, CancellationToken ct = default^);
echo     Task^<Customer^> AddAsync^(Customer customer, CancellationToken ct = default^);
echo     Task UpdateAsync^(Customer customer, CancellationToken ct = default^);
echo     Task DeleteAsync^(Customer customer, CancellationToken ct = default^);
echo     Task^<bool^> ExistsAsync^(CustomerId id, CancellationToken ct = default^);
echo     Task^<Customer?^> GetByEmailAsync^(string email, CancellationToken ct = default^);
echo }
) > "%projectName%.Application\Ports\Output\ICustomerRepository.cs"

(
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo.
echo namespace %projectName%.Application.Ports.Output;
echo.
echo /// ^<summary^>
echo /// Puerto de salida para repositorio de órdenes
echo /// ^</summary^>
echo public interface IOrderRepository
echo {
echo     Task^<Order?^> GetByIdAsync^(OrderId id, CancellationToken ct = default^);
echo     Task^<IEnumerable^<Order^>^> GetAllAsync^(CancellationToken ct = default^);
echo     Task^<IEnumerable^<Order^>^> FindAsync^(ISpecification^<Order^> specification, CancellationToken ct = default^);
echo     Task^<Order^> AddAsync^(Order order, CancellationToken ct = default^);
echo     Task UpdateAsync^(Order order, CancellationToken ct = default^);
echo     Task DeleteAsync^(Order order, CancellationToken ct = default^);
echo     Task^<IEnumerable^<Order^>^> GetByCustomerIdAsync^(CustomerId customerId, CancellationToken ct = default^);
echo }
) > "%projectName%.Application\Ports\Output\IOrderRepository.cs"

(
echo namespace %projectName%.Application.Ports.Output;
echo.
echo /// ^<summary^>
echo /// Puerto de salida para Unit of Work
echo /// ^</summary^>
echo public interface IUnitOfWork
echo {
echo     Task^<int^> SaveChangesAsync^(CancellationToken ct = default^);
echo     Task BeginTransactionAsync^(CancellationToken ct = default^);
echo     Task CommitTransactionAsync^(CancellationToken ct = default^);
echo     Task RollbackTransactionAsync^(CancellationToken ct = default^);
echo }
) > "%projectName%.Application\Ports\Output\IUnitOfWork.cs"

(
echo using %projectName%.Domain.Common;
echo.
echo namespace %projectName%.Application.Ports.Output;
echo.
echo /// ^<summary^>
echo /// Puerto de salida para Event Store
echo /// ^</summary^>
echo public interface IEventStore
echo {
echo     Task SaveEventAsync^(IDomainEvent domainEvent, string aggregateType, int aggregateId, int version, CancellationToken ct = default^);
echo     Task^<IEnumerable^<IDomainEvent^>^> GetEventsAsync^(string aggregateType, int aggregateId, CancellationToken ct = default^);
echo     Task^<IEnumerable^<IDomainEvent^>^> GetAllEventsAsync^(CancellationToken ct = default^);
echo }
) > "%projectName%.Application\Ports\Output\IEventStore.cs"

(
echo using %projectName%.Domain.Common;
echo.
echo namespace %projectName%.Application.Ports.Output;
echo.
echo /// ^<summary^>
echo /// Puerto de salida para Domain Event Dispatcher
echo /// ^</summary^>
echo public interface IDomainEventDispatcher
echo {
echo     Task DispatchAsync^(IDomainEvent domainEvent, CancellationToken ct = default^);
echo     Task DispatchAsync^(IEnumerable^<IDomainEvent^> domainEvents, CancellationToken ct = default^);
echo }
) > "%projectName%.Application\Ports\Output\IDomainEventDispatcher.cs"

echo.
echo [INFO] Creando DTOs (Data Transfer Objects)...

REM ========== DTOs - REQUESTS ==========

(
echo namespace %projectName%.Application.DTOs.Requests;
echo.
echo public record CreateProductRequest
echo {
echo     public string Name { get; init; } = string.Empty;
echo     public decimal Price { get; init; }
echo     public string Currency { get; init; } = "USD";
echo     public string Description { get; init; } = string.Empty;
echo     public int InitialStock { get; init; }
echo }
echo.
echo public record UpdateProductPriceRequest
echo {
echo     public decimal NewPrice { get; init; }
echo     public string Currency { get; init; } = "USD";
echo }
echo.
echo public record UpdateStockRequest
echo {
echo     public int Quantity { get; init; }
echo }
) > "%projectName%.Application\DTOs\Requests\ProductRequests.cs"

(
echo namespace %projectName%.Application.DTOs.Requests;
echo.
echo public record CreateCustomerRequest
echo {
echo     public string FirstName { get; init; } = string.Empty;
echo     public string LastName { get; init; } = string.Empty;
echo     public string Email { get; init; } = string.Empty;
echo }
echo.
echo public record UpdateCustomerEmailRequest
echo {
echo     public string NewEmail { get; init; } = string.Empty;
echo }
) > "%projectName%.Application\DTOs\Requests\CustomerRequests.cs"

(
echo namespace %projectName%.Application.DTOs.Requests;
echo.
echo public record CreateOrderRequest
echo {
echo     public int CustomerId { get; init; }
echo }
echo.
echo public record AddOrderItemRequest
echo {
echo     public int ProductId { get; init; }
echo     public int Quantity { get; init; }
echo }
) > "%projectName%.Application\DTOs\Requests\OrderRequests.cs"

REM ========== DTOs - RESPONSES ==========

(
echo namespace %projectName%.Application.DTOs.Responses;
echo.
echo public record ProductResponse
echo {
echo     public int Id { get; init; }
echo     public string Name { get; init; } = string.Empty;
echo     public decimal Price { get; init; }
echo     public string Currency { get; init; } = string.Empty;
echo     public string Description { get; init; } = string.Empty;
echo     public int Stock { get; init; }
echo     public bool IsActive { get; init; }
echo     public DateTime CreatedAt { get; init; }
echo     public DateTime? UpdatedAt { get; init; }
echo }
) > "%projectName%.Application\DTOs\Responses\ProductResponse.cs"

(
echo namespace %projectName%.Application.DTOs.Responses;
echo.
echo public record CustomerResponse
echo {
echo     public int Id { get; init; }
echo     public string FirstName { get; init; } = string.Empty;
echo     public string LastName { get; init; } = string.Empty;
echo     public string FullName { get; init; } = string.Empty;
echo     public string Email { get; init; } = string.Empty;
echo     public bool IsActive { get; init; }
echo     public DateTime CreatedAt { get; init; }
echo }
) > "%projectName%.Application\DTOs\Responses\CustomerResponse.cs"

(
echo namespace %projectName%.Application.DTOs.Responses;
echo.
echo public record OrderResponse
echo {
echo     public int Id { get; init; }
echo     public int CustomerId { get; init; }
echo     public string CustomerName { get; init; } = string.Empty;
echo     public DateTime OrderDate { get; init; }
echo     public string Status { get; init; } = string.Empty;
echo     public decimal TotalAmount { get; init; }
echo     public string Currency { get; init; } = string.Empty;
echo     public int ItemCount { get; init; }
echo     public List^<OrderItemResponse^> Items { get; init; } = new^(^);
echo }
echo.
echo public record OrderItemResponse
echo {
echo     public int ProductId { get; init; }
echo     public string ProductName { get; init; } = string.Empty;
echo     public int Quantity { get; init; }
echo     public decimal UnitPrice { get; init; }
echo     public decimal Subtotal { get; init; }
echo }
) > "%projectName%.Application\DTOs\Responses\OrderResponse.cs"

echo.
echo [INFO] Creando Validators (FluentValidation)...

REM ========== VALIDATORS ==========

(
echo using FluentValidation;
echo using %projectName%.Application.DTOs.Requests;
echo.
echo namespace %projectName%.Application.Validators;
echo.
echo public class CreateProductRequestValidator : AbstractValidator^<CreateProductRequest^>
echo {
echo     public CreateProductRequestValidator^(^)
echo     {
echo         RuleFor^(x =^> x.Name^)
echo             .NotEmpty^(^).WithMessage^("Product name is required"^)
echo             .MaximumLength^(200^).WithMessage^("Product name cannot exceed 200 characters"^);
echo.
echo         RuleFor^(x =^> x.Price^)
echo             .GreaterThan^(0^).WithMessage^("Price must be greater than zero"^);
echo.
echo         RuleFor^(x =^> x.Currency^)
echo             .NotEmpty^(^).WithMessage^("Currency is required"^)
echo             .Length^(3^).WithMessage^("Currency must be 3 characters"^);
echo.
echo         RuleFor^(x =^> x.InitialStock^)
echo             .GreaterThanOrEqualTo^(0^).WithMessage^("Stock cannot be negative"^);
echo.
echo         RuleFor^(x =^> x.Description^)
echo             .MaximumLength^(1000^).WithMessage^("Description cannot exceed 1000 characters"^);
echo     }
echo }
echo.
echo public class UpdateProductPriceRequestValidator : AbstractValidator^<UpdateProductPriceRequest^>
echo {
echo     public UpdateProductPriceRequestValidator^(^)
echo     {
echo         RuleFor^(x =^> x.NewPrice^)
echo             .GreaterThan^(0^).WithMessage^("Price must be greater than zero"^);
echo.
echo         RuleFor^(x =^> x.Currency^)
echo             .NotEmpty^(^).WithMessage^("Currency is required"^)
echo             .Length^(3^).WithMessage^("Currency must be 3 characters"^);
echo     }
echo }
echo.
echo public class UpdateStockRequestValidator : AbstractValidator^<UpdateStockRequest^>
echo {
echo     public UpdateStockRequestValidator^(^)
echo     {
echo         RuleFor^(x =^> x.Quantity^)
echo             .GreaterThan^(0^).WithMessage^("Quantity must be greater than zero"^);
echo     }
echo }
) > "%projectName%.Application\Validators\ProductValidators.cs"

(
echo using FluentValidation;
echo using %projectName%.Application.DTOs.Requests;
echo.
echo namespace %projectName%.Application.Validators;
echo.
echo public class CreateCustomerRequestValidator : AbstractValidator^<CreateCustomerRequest^>
echo {
echo     public CreateCustomerRequestValidator^(^)
echo     {
echo         RuleFor^(x =^> x.FirstName^)
echo             .NotEmpty^(^).WithMessage^("First name is required"^)
echo             .MaximumLength^(100^).WithMessage^("First name cannot exceed 100 characters"^);
echo.
echo         RuleFor^(x =^> x.LastName^)
echo             .NotEmpty^(^).WithMessage^("Last name is required"^)
echo             .MaximumLength^(100^).WithMessage^("Last name cannot exceed 100 characters"^);
echo.
echo         RuleFor^(x =^> x.Email^)
echo             .NotEmpty^(^).WithMessage^("Email is required"^)
echo             .EmailAddress^(^).WithMessage^("Invalid email format"^);
echo     }
echo }
) > "%projectName%.Application\Validators\CustomerValidators.cs"

(
echo using FluentValidation;
echo using %projectName%.Application.DTOs.Requests;
echo.
echo namespace %projectName%.Application.Validators;
echo.
echo public class CreateOrderRequestValidator : AbstractValidator^<CreateOrderRequest^>
echo {
echo     public CreateOrderRequestValidator^(^)
echo     {
echo         RuleFor^(x =^> x.CustomerId^)
echo             .GreaterThan^(0^).WithMessage^("Invalid customer ID"^);
echo     }
echo }
echo.
echo public class AddOrderItemRequestValidator : AbstractValidator^<AddOrderItemRequest^>
echo {
echo     public AddOrderItemRequestValidator^(^)
echo     {
echo         RuleFor^(x =^> x.ProductId^)
echo             .GreaterThan^(0^).WithMessage^("Invalid product ID"^);
echo.
echo         RuleFor^(x =^> x.Quantity^)
echo             .GreaterThan^(0^).WithMessage^("Quantity must be greater than zero"^);
echo     }
echo }
) > "%projectName%.Application\Validators\OrderValidators.cs"

echo.
echo [OK] Application Layer - Ports y DTOs creados
echo.
REM ============================================================
REM === PARTE 5: USE CASES IMPLEMENTATION ^& BEHAVIORS ===
REM ============================================================

echo.
echo [INFO] Creando Use Cases (Implementación de Casos de Uso)...

REM ========== PRODUCT USE CASES ==========

(
echo using %projectName%.Application.DTOs.Requests;
echo using %projectName%.Application.DTOs.Responses;
echo using %projectName%.Application.Exceptions;
echo using %projectName%.Application.Ports.Input;
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Application.UseCases.Products;
echo.
echo /// ^<summary^>
echo /// Implementación de casos de uso para productos
echo /// ^</summary^>
echo public class ProductService : IProductService
echo {
echo     private readonly IProductRepository _repository;
echo     private readonly IUnitOfWork _unitOfWork;
echo     private readonly IDomainEventDispatcher _eventDispatcher;
echo.
echo     public ProductService^(
echo         IProductRepository repository,
echo         IUnitOfWork unitOfWork,
echo         IDomainEventDispatcher eventDispatcher^)
echo     {
echo         _repository = repository;
echo         _unitOfWork = unitOfWork;
echo         _eventDispatcher = eventDispatcher;
echo     }
echo.
echo     public async Task^<ProductResponse^> CreateProductAsync^(CreateProductRequest request, CancellationToken ct^)
echo     {
echo         var price = Money.Create^(request.Price, request.Currency^);
echo         var product = Product.Create^(
echo             ProductId.Create^(^),
echo             request.Name,
echo             price,
echo             request.Description,
echo             request.InitialStock^);
echo.
echo         await _repository.AddAsync^(product, ct^);
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(product.DomainEvents, ct^);
echo.
echo         return MapToResponse^(product^);
echo     }
echo.
echo     public async Task^<ProductResponse^> GetProductByIdAsync^(int id, CancellationToken ct^)
echo     {
echo         var product = await _repository.GetByIdAsync^(ProductId.From^(id^), ct^);
echo         if ^(product == null^)
echo             throw new EntityNotFoundException^("Product", id^);
echo.
echo         return MapToResponse^(product^);
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductResponse^>^> GetAllProductsAsync^(CancellationToken ct^)
echo     {
echo         var products = await _repository.GetAllAsync^(ct^);
echo         return products.Select^(MapToResponse^);
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductResponse^>^> GetActiveProductsAsync^(CancellationToken ct^)
echo     {
echo         var specification = new ActiveProductsSpecification^(^);
echo         var products = await _repository.FindAsync^(specification, ct^);
echo         return products.Select^(MapToResponse^);
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductResponse^>^> GetProductsInStockAsync^(CancellationToken ct^)
echo     {
echo         var specification = new ProductsInStockSpecification^(^);
echo         var products = await _repository.FindAsync^(specification, ct^);
echo         return products.Select^(MapToResponse^);
echo     }
echo.
echo     public async Task^<IEnumerable^<ProductResponse^>^> GetProductsByPriceRangeAsync^(
echo         decimal minPrice, 
echo         decimal maxPrice, 
echo         CancellationToken ct^)
echo     {
echo         var specification = new ProductsByPriceRangeSpecification^(minPrice, maxPrice^);
echo         var products = await _repository.FindAsync^(specification, ct^);
echo         return products.Select^(MapToResponse^);
echo     }
echo.
echo     public async Task^<bool^> UpdateProductPriceAsync^(int id, decimal newPrice, CancellationToken ct^)
echo     {
echo         var product = await _repository.GetByIdAsync^(ProductId.From^(id^), ct^);
echo         if ^(product == null^) return false;
echo.
echo         var price = Money.Create^(newPrice, product.Price.Currency^);
echo         product.UpdatePrice^(price^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(product.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo.
echo     public async Task^<bool^> AddStockAsync^(int id, int quantity, CancellationToken ct^)
echo     {
echo         var product = await _repository.GetByIdAsync^(ProductId.From^(id^), ct^);
echo         if ^(product == null^) return false;
echo.
echo         product.AddStock^(quantity^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(product.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo.
echo     public async Task^<bool^> RemoveStockAsync^(int id, int quantity, CancellationToken ct^)
echo     {
echo         var product = await _repository.GetByIdAsync^(ProductId.From^(id^), ct^);
echo         if ^(product == null^) return false;
echo.
echo         product.RemoveStock^(quantity^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(product.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo.
echo     public async Task^<bool^> DeactivateProductAsync^(int id, CancellationToken ct^)
echo     {
echo         var product = await _repository.GetByIdAsync^(ProductId.From^(id^), ct^);
echo         if ^(product == null^) return false;
echo.
echo         product.Deactivate^(^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(product.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo.
echo     public async Task^<bool^> ActivateProductAsync^(int id, CancellationToken ct^)
echo     {
echo         var product = await _repository.GetByIdAsync^(ProductId.From^(id^), ct^);
echo         if ^(product == null^) return false;
echo.
echo         product.Activate^(^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(product.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo.
echo     private static ProductResponse MapToResponse^(Product product^) =^> new^(^)
echo     {
echo         Id = product.Id.Value,
echo         Name = product.Name,
echo         Price = product.Price.Amount,
echo         Currency = product.Price.Currency,
echo         Description = product.Description,
echo         Stock = product.Stock,
echo         IsActive = product.IsActive,
echo         CreatedAt = product.CreatedAt,
echo         UpdatedAt = product.UpdatedAt
echo     };
echo }
) > "%projectName%.Application\UseCases\Products\ProductService.cs"

REM ========== CUSTOMER USE CASES ==========

(
echo using %projectName%.Application.DTOs.Requests;
echo using %projectName%.Application.DTOs.Responses;
echo using %projectName%.Application.Exceptions;
echo using %projectName%.Application.Ports.Input;
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Application.UseCases.Customers;
echo.
echo /// ^<summary^>
echo /// Implementación de casos de uso para clientes
echo /// ^</summary^>
echo public class CustomerService : ICustomerService
echo {
echo     private readonly ICustomerRepository _repository;
echo     private readonly IUnitOfWork _unitOfWork;
echo     private readonly IDomainEventDispatcher _eventDispatcher;
echo.
echo     public CustomerService^(
echo         ICustomerRepository repository,
echo         IUnitOfWork unitOfWork,
echo         IDomainEventDispatcher eventDispatcher^)
echo     {
echo         _repository = repository;
echo         _unitOfWork = unitOfWork;
echo         _eventDispatcher = eventDispatcher;
echo     }
echo.
echo     public async Task^<CustomerResponse^> CreateCustomerAsync^(CreateCustomerRequest request, CancellationToken ct^)
echo     {
echo         // Verificar que el email no exista
echo         var existingCustomer = await _repository.GetByEmailAsync^(request.Email, ct^);
echo         if ^(existingCustomer != null^)
echo             throw new ApplicationException^($"Customer with email {request.Email} already exists"^);
echo.
echo         var email = Email.Create^(request.Email^);
echo         var customer = Customer.Create^(
echo             CustomerId.Create^(^),
echo             request.FirstName,
echo             request.LastName,
echo             email^);
echo.
echo         await _repository.AddAsync^(customer, ct^);
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(customer.DomainEvents, ct^);
echo.
echo         return MapToResponse^(customer^);
echo     }
echo.
echo     public async Task^<CustomerResponse^> GetCustomerByIdAsync^(int id, CancellationToken ct^)
echo     {
echo         var customer = await _repository.GetByIdAsync^(CustomerId.From^(id^), ct^);
echo         if ^(customer == null^)
echo             throw new EntityNotFoundException^("Customer", id^);
echo.
echo         return MapToResponse^(customer^);
echo     }
echo.
echo     public async Task^<IEnumerable^<CustomerResponse^>^> GetAllCustomersAsync^(CancellationToken ct^)
echo     {
echo         var customers = await _repository.GetAllAsync^(ct^);
echo         return customers.Select^(MapToResponse^);
echo     }
echo.
echo     public async Task^<IEnumerable^<CustomerResponse^>^> GetActiveCustomersAsync^(CancellationToken ct^)
echo     {
echo         var specification = new ActiveCustomersSpecification^(^);
echo         var customers = await _repository.FindAsync^(specification, ct^);
echo         return customers.Select^(MapToResponse^);
echo     }
echo.
echo     public async Task^<bool^> UpdateCustomerEmailAsync^(int id, string newEmail, CancellationToken ct^)
echo     {
echo         var customer = await _repository.GetByIdAsync^(CustomerId.From^(id^), ct^);
echo         if ^(customer == null^) return false;
echo.
echo         var email = Email.Create^(newEmail^);
echo         customer.UpdateEmail^(email^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(customer.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo.
echo     public async Task^<bool^> DeactivateCustomerAsync^(int id, CancellationToken ct^)
echo     {
echo         var customer = await _repository.GetByIdAsync^(CustomerId.From^(id^), ct^);
echo         if ^(customer == null^) return false;
echo.
echo         customer.Deactivate^(^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(customer.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo.
echo     private static CustomerResponse MapToResponse^(Customer customer^) =^> new^(^)
echo     {
echo         Id = customer.Id.Value,
echo         FirstName = customer.FirstName,
echo         LastName = customer.LastName,
echo         FullName = customer.GetFullName^(^),
echo         Email = customer.Email.Address,
echo         IsActive = customer.IsActive,
echo         CreatedAt = customer.CreatedAt
echo     };
echo }
) > "%projectName%.Application\UseCases\Customers\CustomerService.cs"

REM ========== ORDER USE CASES ==========

(
echo using %projectName%.Application.DTOs.Requests;
echo using %projectName%.Application.DTOs.Responses;
echo using %projectName%.Application.Exceptions;
echo using %projectName%.Application.Ports.Input;
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo.
echo namespace %projectName%.Application.UseCases.Orders;
echo.
echo /// ^<summary^>
echo /// Implementación de casos de uso para órdenes
echo /// ^</summary^>
echo public class OrderService : IOrderService
echo {
echo     private readonly IOrderRepository _orderRepository;
echo     private readonly ICustomerRepository _customerRepository;
echo     private readonly IProductRepository _productRepository;
echo     private readonly IUnitOfWork _unitOfWork;
echo     private readonly IDomainEventDispatcher _eventDispatcher;
echo.
echo     public OrderService^(
echo         IOrderRepository orderRepository,
echo         ICustomerRepository customerRepository,
echo         IProductRepository productRepository,
echo         IUnitOfWork unitOfWork,
echo         IDomainEventDispatcher eventDispatcher^)
echo     {
echo         _orderRepository = orderRepository;
echo         _customerRepository = customerRepository;
echo         _productRepository = productRepository;
echo         _unitOfWork = unitOfWork;
echo         _eventDispatcher = eventDispatcher;
echo     }
echo.
echo     public async Task^<OrderResponse^> CreateOrderAsync^(CreateOrderRequest request, CancellationToken ct^)
echo     {
echo         var customerId = CustomerId.From^(request.CustomerId^);
echo         var customerExists = await _customerRepository.ExistsAsync^(customerId, ct^);
echo         
echo         if ^(!customerExists^)
echo             throw new EntityNotFoundException^("Customer", request.CustomerId^);
echo.
echo         var order = Order.Create^(OrderId.Create^(^), customerId^);
echo.
echo         await _orderRepository.AddAsync^(order, ct^);
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(order.DomainEvents, ct^);
echo.
echo         return await MapToResponseAsync^(order, ct^);
echo     }
echo.
echo     public async Task^<OrderResponse^> GetOrderByIdAsync^(int id, CancellationToken ct^)
echo     {
echo         var order = await _orderRepository.GetByIdAsync^(OrderId.From^(id^), ct^);
echo         if ^(order == null^)
echo             throw new EntityNotFoundException^("Order", id^);
echo.
echo         return await MapToResponseAsync^(order, ct^);
echo     }
echo.
echo     public async Task^<IEnumerable^<OrderResponse^>^> GetOrdersByCustomerAsync^(int customerId, CancellationToken ct^)
echo     {
echo         var specification = new OrdersByCustomerSpecification^(CustomerId.From^(customerId^)^);
echo         var orders = await _orderRepository.FindAsync^(specification, ct^);
echo         
echo         var responses = new List^<OrderResponse^>^(^);
echo         foreach ^(var order in orders^)
echo         {
echo             responses.Add^(await MapToResponseAsync^(order, ct^)^);
echo         }
echo         
echo         return responses;
echo     }
echo.
echo     public async Task^<IEnumerable^<OrderResponse^>^> GetPendingOrdersAsync^(CancellationToken ct^)
echo     {
echo         var specification = new PendingOrdersSpecification^(^);
echo         var orders = await _orderRepository.FindAsync^(specification, ct^);
echo         
echo         var responses = new List^<OrderResponse^>^(^);
echo         foreach ^(var order in orders^)
echo         {
echo             responses.Add^(await MapToResponseAsync^(order, ct^)^);
echo         }
echo         
echo         return responses;
echo     }
echo.
echo     public async Task^<bool^> AddItemToOrderAsync^(int orderId, AddOrderItemRequest request, CancellationToken ct^)
echo     {
echo         var order = await _orderRepository.GetByIdAsync^(OrderId.From^(orderId^), ct^);
echo         if ^(order == null^) return false;
echo.
echo         var product = await _productRepository.GetByIdAsync^(ProductId.From^(request.ProductId^), ct^);
echo         if ^(product == null^)
echo             throw new EntityNotFoundException^("Product", request.ProductId^);
echo.
echo         order.AddItem^(product.Id, product.Price, request.Quantity^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo.
echo         return true;
echo     }
echo.
echo     public async Task^<bool^> ConfirmOrderAsync^(int id, CancellationToken ct^)
echo     {
echo         var order = await _orderRepository.GetByIdAsync^(OrderId.From^(id^), ct^);
echo         if ^(order == null^) return false;
echo.
echo         order.Confirm^(^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(order.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo.
echo     public async Task^<bool^> ShipOrderAsync^(int id, CancellationToken ct^)
echo     {
echo         var order = await _orderRepository.GetByIdAsync^(OrderId.From^(id^), ct^);
echo         if ^(order == null^) return false;
echo.
echo         order.Ship^(^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(order.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo.
echo     public async Task^<bool^> DeliverOrderAsync^(int id, CancellationToken ct^)
echo     {
echo         var order = await _orderRepository.GetByIdAsync^(OrderId.From^(id^), ct^);
echo         if ^(order == null^) return false;
echo.
echo         order.Deliver^(^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(order.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo.
echo     public async Task^<bool^> CancelOrderAsync^(int id, CancellationToken ct^)
echo     {
echo         var order = await _orderRepository.GetByIdAsync^(OrderId.From^(id^), ct^);
echo         if ^(order == null^) return false;
echo.
echo         order.Cancel^(^);
echo.
echo         await _unitOfWork.SaveChangesAsync^(ct^);
echo         await _eventDispatcher.DispatchAsync^(order.DomainEvents, ct^);
echo.
echo         return true;
echo     }
echo.
echo     private async Task^<OrderResponse^> MapToResponseAsync^(Order order, CancellationToken ct^)
echo     {
echo         var customer = await _customerRepository.GetByIdAsync^(order.CustomerId, ct^);
echo         var total = order.CalculateTotal^(^);
echo.
echo         return new OrderResponse
echo         {
echo             Id = order.Id.Value,
echo             CustomerId = order.CustomerId.Value,
echo             CustomerName = customer?.GetFullName^(^) ?? "Unknown",
echo             OrderDate = order.OrderDate,
echo             Status = order.Status.ToString^(^),
echo             TotalAmount = total.Amount,
echo             Currency = total.Currency,
echo             ItemCount = order.GetItemCount^(^),
echo             Items = order.Items.Select^(item =^> new OrderItemResponse
echo             {
echo                 ProductId = item.ProductId.Value,
echo                 ProductName = "Product",
echo                 Quantity = item.Quantity,
echo                 UnitPrice = item.UnitPrice.Amount,
echo                 Subtotal = item.GetSubtotal^(^).Amount
echo             }^).ToList^(^)
echo         };
echo     }
echo }
) > "%projectName%.Application\UseCases\Orders\OrderService.cs"

echo.
echo [INFO] Creando Behaviors (Pipeline Behaviors)...

REM ========== BEHAVIORS ==========

(
echo using FluentValidation;
echo.
echo namespace %projectName%.Application.Behaviors;
echo.
echo /// ^<summary^>
echo /// Pipeline behavior para validación automática
echo /// ^</summary^>
echo public class ValidationBehavior^<TRequest, TResponse^>
echo {
echo     private readonly IEnumerable^<IValidator^<TRequest^>^> _validators;
echo.
echo     public ValidationBehavior^(IEnumerable^<IValidator^<TRequest^>^> validators^)
echo     {
echo         _validators = validators;
echo     }
echo.
echo     public async Task^<TResponse^> Handle^(
echo         TRequest request,
echo         Func^<Task^<TResponse^>^> next,
echo         CancellationToken cancellationToken^)
echo     {
echo         if ^(!_validators.Any^(^)^)
echo             return await next^(^);
echo.
echo         var context = new ValidationContext^<TRequest^>^(request^);
echo         var validationResults = await Task.WhenAll^(
echo             _validators.Select^(v =^> v.ValidateAsync^(context, cancellationToken^)^)^);
echo.
echo         var failures = validationResults
echo             .SelectMany^(r =^> r.Errors^)
echo             .Where^(f =^> f != null^)
echo             .ToList^(^);
echo.
echo         if ^(failures.Any^(^)^)
echo             throw new ValidationException^(failures^);
echo.
echo         return await next^(^);
echo     }
echo }
) > "%projectName%.Application\Behaviors\ValidationBehavior.cs"

(
echo using Microsoft.Extensions.Logging;
echo using System.Diagnostics;
echo.
echo namespace %projectName%.Application.Behaviors;
echo.
echo /// ^<summary^>
echo /// Pipeline behavior para logging de performance
echo /// ^</summary^>
echo public class PerformanceBehavior^<TRequest, TResponse^>
echo {
echo     private readonly ILogger^<PerformanceBehavior^<TRequest, TResponse^>^> _logger;
echo     private readonly Stopwatch _timer;
echo.
echo     public PerformanceBehavior^(ILogger^<PerformanceBehavior^<TRequest, TResponse^>^> logger^)
echo     {
echo         _logger = logger;
echo         _timer = new Stopwatch^(^);
echo     }
echo.
echo     public async Task^<TResponse^> Handle^(
echo         TRequest request,
echo         Func^<Task^<TResponse^>^> next,
echo         CancellationToken cancellationToken^)
echo     {
echo         _timer.Start^(^);
echo.
echo         var response = await next^(^);
echo.
echo         _timer.Stop^(^);
echo.
echo         var elapsedMilliseconds = _timer.ElapsedMilliseconds;
echo.
echo         if ^(elapsedMilliseconds ^> 500^)
echo         {
echo             var requestName = typeof^(TRequest^).Name;
echo             _logger.LogWarning^(
echo                 "Long Running Request: {Name} ({ElapsedMilliseconds} milliseconds) {@Request}",
echo                 requestName, elapsedMilliseconds, request^);
echo         }
echo.
echo         return response;
echo     }
echo }
) > "%projectName%.Application\Behaviors\PerformanceBehavior.cs"

(
echo using Microsoft.Extensions.Logging;
echo.
echo namespace %projectName%.Application.Behaviors;
echo.
echo /// ^<summary^>
echo /// Pipeline behavior para logging
echo /// ^</summary^>
echo public class LoggingBehavior^<TRequest, TResponse^>
echo {
echo     private readonly ILogger^<LoggingBehavior^<TRequest, TResponse^>^> _logger;
echo.
echo     public LoggingBehavior^(ILogger^<LoggingBehavior^<TRequest, TResponse^>^> logger^)
echo     {
echo         _logger = logger;
echo     }
echo.
echo     public async Task^<TResponse^> Handle^(
echo         TRequest request,
echo         Func^<Task^<TResponse^>^> next,
echo         CancellationToken cancellationToken^)
echo     {
echo         var requestName = typeof^(TRequest^).Name;
echo.
echo         _logger.LogInformation^("Handling {RequestName}", requestName^);
echo.
echo         var response = await next^(^);
echo.
echo         _logger.LogInformation^("Handled {RequestName}", requestName^);
echo.
echo         return response;
echo     }
echo }
) > "%projectName%.Application\Behaviors\LoggingBehavior.cs"

echo.
echo [INFO] Creando Exception Handlers...

REM ========== EXCEPTIONS ==========

(
echo namespace %projectName%.Application.Exceptions;
echo.
echo public class ApplicationException : Exception
echo {
echo     public ApplicationException^(^) : base^(^) { }
echo     public ApplicationException^(string message^) : base^(message^) { }
echo     public ApplicationException^(string message, Exception innerException^)
echo         : base^(message, innerException^) { }
echo }
echo.
echo public class EntityNotFoundException : ApplicationException
echo {
echo     public EntityNotFoundException^(string entityName, object key^)
echo         : base^($"{entityName} with key '{key}' was not found."^)
echo     {
echo         EntityName = entityName;
echo         Key = key;
echo     }
echo.
echo     public string EntityName { get; }
echo     public object Key { get; }
echo }
echo.
echo public class ValidationException : ApplicationException
echo {
echo     public ValidationException^(^)
echo         : base^("One or more validation failures have occurred."^)
echo     {
echo         Errors = new Dictionary^<string, string[]^>^(^);
echo     }
echo.
echo     public ValidationException^(IEnumerable^<FluentValidation.Results.ValidationFailure^> failures^)
echo         : this^(^)
echo     {
echo         Errors = failures
echo             .GroupBy^(e =^> e.PropertyName, e =^> e.ErrorMessage^)
echo             .ToDictionary^(failureGroup =^> failureGroup.Key, failureGroup =^> failureGroup.ToArray^(^)^);
echo     }
echo.
echo     public IDictionary^<string, string[]^> Errors { get; }
echo }
) > "%projectName%.Application\Exceptions\ApplicationExceptions.cs"

echo.
echo [INFO] Creando Dependency Injection...

REM ========== DEPENDENCY INJECTION ==========

(
echo using System.Reflection;
echo using FluentValidation;
echo using Microsoft.Extensions.DependencyInjection;
echo using %projectName%.Application.Ports.Input;
echo using %projectName%.Application.UseCases.Customers;
echo using %projectName%.Application.UseCases.Orders;
echo using %projectName%.Application.UseCases.Products;
echo.
echo namespace %projectName%.Application;
echo.
echo /// ^<summary^>
echo /// Configuración de dependencias de la capa de aplicación
echo /// ^</summary^>
echo public static class DependencyInjection
echo {
echo     public static IServiceCollection AddApplication^(this IServiceCollection services^)
echo     {
echo         var assembly = Assembly.GetExecutingAssembly^(^);
echo.
echo         // Registrar validadores
echo         services.AddValidatorsFromAssembly^(assembly^);
echo.
echo         // Registrar servicios de aplicación (Use Cases)
echo         services.AddScoped^<IProductService, ProductService^>^(^);
echo         services.AddScoped^<ICustomerService, CustomerService^>^(^);
echo         services.AddScoped^<IOrderService, OrderService^>^(^);
echo.
echo         return services;
echo     }
echo }
) > "%projectName%.Application\DependencyInjection.cs"

echo.
echo [SUCCESS] Application Layer completado!
echo.
echo Componentes creados:
echo   [+] Input Ports (IProductService, ICustomerService, IOrderService)
echo   [+] Output Ports (IRepository interfaces, IUnitOfWork, IEventStore)
echo   [+] Use Cases completos (ProductService, CustomerService, OrderService)
echo   [+] DTOs (Requests ^& Responses)
echo   [+] Validators (FluentValidation)
echo   [+] Behaviors (Validation, Logging, Performance)
echo   [+] Exception Handling
echo   [+] Dependency Injection
echo.
REM ============================================================
REM === PARTE 6: INFRASTRUCTURE LAYER (ADAPTADORES SECUNDARIOS) ===
REM ============================================================

echo.
echo ============================================================
echo === CREANDO INFRASTRUCTURE LAYER (ADAPTERS) ===
echo ============================================================

REM Estructura de carpetas Infrastructure
mkdir "%projectName%.Infrastructure\Adapters"
mkdir "%projectName%.Infrastructure\Adapters\Persistence"
mkdir "%projectName%.Infrastructure\Adapters\Persistence\Configurations"
mkdir "%projectName%.Infrastructure\Adapters\Persistence\Repositories"
mkdir "%projectName%.Infrastructure\Adapters\EventSourcing"
mkdir "%projectName%.Infrastructure\Adapters\Messaging"
mkdir "%projectName%.Infrastructure\Common"

echo.
echo [INFO] Creando configuraciones de EF Core...

REM ========== EF CONFIGURATIONS ==========
(
echo using Microsoft.EntityFrameworkCore;
echo using Microsoft.EntityFrameworkCore.Metadata.Builders;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo.
echo namespace %projectName%.Infrastructure.Adapters.Persistence.Configurations;
echo.
echo /// ^<summary^>
echo /// Configuracion de Entity Framework para Product
echo /// ^</summary^>
echo public class ProductConfiguration : IEntityTypeConfiguration^<Product^>
echo {
echo     public void Configure^(EntityTypeBuilder^<Product^> builder^)
echo     {
echo         builder.ToTable^("Products"^);
echo         builder.HasKey^(p =^> p.Id^);
echo.
echo         builder.Property^(p =^> p.Id^)
echo             .HasConversion^(
echo                 id =^> id.Value,
echo                 value =^> ProductId.From^(value^)^)
echo             .ValueGeneratedOnAdd^(^)
echo             .HasColumnName^("ProductId"^);
echo.
echo         builder.Property^<string^>^("_name"^)
echo             .HasColumnName^("Name"^)
echo             .IsRequired^(^)
echo             .HasMaxLength^(200^);
echo.
echo         builder.Property^<string^>^("_description"^)
echo             .HasColumnName^("Description"^)
echo             .HasMaxLength^(1000^);
echo.
echo         builder.Property^<int^>^("_stock"^)
echo             .HasColumnName^("Stock"^);
echo.
echo         builder.Property^<bool^>^("_isActive"^)
echo             .HasColumnName^("IsActive"^);
echo.
echo         builder.OwnsOne^<Money^>^("_price", price =^>
echo         {
echo             price.Property^(m =^> m.Amount^)
echo                 .HasColumnName^("Price"^)
echo                 .HasColumnType^("decimal^(18,2^)"^)
echo                 .IsRequired^(^);
echo.
echo             price.Property^(m =^> m.Currency^)
echo                 .HasColumnName^("Currency"^)
echo                 .HasMaxLength^(3^)
echo                 .IsRequired^(^);
echo         }^);
echo.
echo         builder.Property^(p =^> p.CreatedAt^)
echo             .IsRequired^(^);
echo.
echo         builder.Property^(p =^> p.UpdatedAt^);
echo.
echo         builder.Property^(p =^> p.Version^)
echo             .IsConcurrencyToken^(^);
echo.
echo         builder.Ignore^(p =^> p.DomainEvents^);
echo.
echo         builder.HasIndex^<string^>^("_name"^);
echo         builder.HasIndex^<bool^>^("_isActive"^);
echo     }
echo }
) > "%projectName%.Infrastructure\Adapters\Persistence\Configurations\ProductConfiguration.cs"
(
echo using Microsoft.EntityFrameworkCore;
echo using Microsoft.EntityFrameworkCore.Metadata.Builders;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.ValueObjects;
echo.
echo namespace %projectName%.Infrastructure.Adapters.Persistence.Configurations;
echo.
echo /// ^<summary^>
echo /// Configuracion de Entity Framework para Customer
echo /// ^</summary^>
echo public class CustomerConfiguration : IEntityTypeConfiguration^<Customer^>
echo {
echo     public void Configure^(EntityTypeBuilder^<Customer^> builder^)
echo     {
echo         builder.ToTable^("Customers"^);
echo         builder.HasKey^(c =^> c.Id^);
echo.
echo         builder.Property^(c =^> c.Id^)
echo             .HasConversion^(
echo                 id =^> id.Value,
echo                 value =^> CustomerId.From^(value^)^)
echo             .ValueGeneratedOnAdd^(^)
echo             .HasColumnName^("CustomerId"^);
echo.
echo         builder.Property^<string^>^("_firstName"^)
echo             .HasColumnName^("FirstName"^)
echo             .IsRequired^(^)
echo             .HasMaxLength^(100^);
echo.
echo         builder.Property^<string^>^("_lastName"^)
echo             .HasColumnName^("LastName"^)
echo             .IsRequired^(^)
echo             .HasMaxLength^(100^);
echo.
echo         builder.Property^<bool^>^("_isActive"^)
echo             .HasColumnName^("IsActive"^);
echo.
echo         builder.OwnsOne^<Email^>^("_email", email =^>
echo         {
echo             email.Property^(e =^> e.Address^)
echo                 .HasColumnName^("Email"^)
echo                 .IsRequired^(^)
echo                 .HasMaxLength^(256^);
echo         }^);
echo.
echo         builder.Property^(c =^> c.CreatedAt^).IsRequired^(^);
echo         builder.Property^(c =^> c.UpdatedAt^);
echo         builder.Property^(c =^> c.Version^).IsConcurrencyToken^(^);
echo.
echo         builder.Ignore^(c =^> c.DomainEvents^);
echo.
echo         builder.HasIndex^<Email^>^("_email"^).IsUnique^(^);
echo     }
echo }
) > "%projectName%.Infrastructure\Adapters\Persistence\Configurations\CustomerConfiguration.cs"
(
echo using Microsoft.EntityFrameworkCore;
echo using Microsoft.EntityFrameworkCore.Metadata.Builders;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Entities;
echo.
echo namespace %projectName%.Infrastructure.Adapters.Persistence.Configurations;
echo.
echo /// ^<summary^>
echo /// Configuración de Entity Framework para Order
echo /// ^</summary^>
echo public class OrderConfiguration : IEntityTypeConfiguration^<Order^>
echo {
echo     public void Configure^(EntityTypeBuilder^<Order^> builder^)
echo     {
echo         builder.ToTable^("Orders"^);
echo         builder.HasKey^(o =^> o.Id^);
echo.
echo         // Conversión de OrderId
echo         builder.Property^(o =^> o.Id^)
echo             .HasConversion^(
echo                 id =^> id.Value,
echo                 value =^> OrderId.From^(value^)^)
echo             .ValueGeneratedOnAdd^(^)
echo             .HasColumnName^("OrderId"^);
echo.
echo         // Conversión de CustomerId (FK)
echo         builder.Property^<CustomerId^>^("_customerId"^)
echo             .HasConversion^(
echo                 id =^> id.Value,
echo                 value =^> CustomerId.From^(value^)^)
echo             .HasColumnName^("CustomerId"^)
echo             .IsRequired^(^);
echo.
echo         // Relación con Customer
echo         builder.HasOne^<Customer^>^(^)
echo             .WithMany^(^)
echo             .HasForeignKey^<CustomerId^>^("_customerId"^)
echo             .OnDelete^(DeleteBehavior.Restrict^);
echo.
echo         // Propiedades
echo         builder.Property^<DateTime^>^("_orderDate"^)
echo             .HasColumnName^("OrderDate"^)
echo             .IsRequired^(^);
echo.
echo         builder.Property^<OrderStatus^>^("_status"^)
echo             .HasColumnName^("Status"^)
echo             .HasConversion^<string^>^(^)
echo             .IsRequired^(^);
echo.
echo         // Entidades hijo (OrderItems)
echo         builder.OwnsMany^<OrderItem^>^("_items", items =^>
echo         {
echo             items.ToTable^("OrderItems"^);
echo             items.WithOwner^(^).HasForeignKey^("OrderId"^);
echo             items.HasKey^(i =^> i.Id^);
echo.
echo             items.Property^(i =^> i.Id^)
echo                 .HasConversion^(
echo                     id =^> id.Value,
echo                     value =^> OrderItemId.From^(value^)^)
echo                 .ValueGeneratedOnAdd^(^)
echo                 .HasColumnName^("OrderItemId"^);
echo.
echo             items.Property^<ProductId^>^("_productId"^)
echo                 .HasConversion^(
echo                     id =^> id.Value,
echo                     value =^> ProductId.From^(value^)^)
echo                 .HasColumnName^("ProductId"^)
echo                 .IsRequired^(^);
echo.
echo             items.Property^<int^>^("_quantity"^)
echo                 .HasColumnName^("Quantity"^)
echo                 .IsRequired^(^);
echo.
echo             items.OwnsOne^<Money^>^("_unitPrice", price =^>
echo             {
echo                 price.Property^(m =^> m.Amount^)
echo                     .HasColumnName^("UnitPrice"^)
echo                     .HasColumnType^("decimal(18,2)"^)
echo                     .IsRequired^(^);
echo.
echo                 price.Property^(m =^> m.Currency^)
echo                     .HasColumnName^("Currency"^)
echo                     .HasMaxLength^(3^)
echo                     .IsRequired^(^);
echo             }^);
echo.
echo             items.Ignore^(i =^> i.DomainEvents^);
echo         }^);
echo.
echo         // Propiedades de auditoría
echo         builder.Property^(o =^> o.CreatedAt^).IsRequired^(^);
echo         builder.Property^(o =^> o.UpdatedAt^);
echo         builder.Property^(o =^> o.Version^).IsConcurrencyToken^(^);
echo.
echo         // Ignorar eventos de dominio
echo         builder.Ignore^(o =^> o.DomainEvents^);
echo.
echo         // Índices
echo         builder.HasIndex^<CustomerId^>^("_customerId"^);
echo         builder.HasIndex^<OrderStatus^>^("_status"^);
echo     }
echo }
) > "%projectName%.Infrastructure\Adapters\Persistence\Configurations\OrderConfiguration.cs"

echo.
echo [INFO] Creando DbContext...

REM ========== DB CONTEXT ==========

(
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Domain.Aggregates;
echo using System.Reflection;
echo.
echo namespace %projectName%.Infrastructure.Adapters.Persistence;
echo.
echo /// ^<summary^>
echo /// Contexto de base de datos principal
echo /// ^</summary^>
echo public class ApplicationDbContext : DbContext
echo {
echo     public DbSet^<Product^> Products { get; set; } = null!;
echo     public DbSet^<Customer^> Customers { get; set; } = null!;
echo     public DbSet^<Order^> Orders { get; set; } = null!;
echo.
echo     public ApplicationDbContext^(DbContextOptions^<ApplicationDbContext^> options^)
echo         : base^(options^)
echo     {
echo     }
echo.
echo     protected override void OnModelCreating^(ModelBuilder modelBuilder^)
echo     {
echo         // Aplicar todas las configuraciones del assembly
echo         modelBuilder.ApplyConfigurationsFromAssembly^(Assembly.GetExecutingAssembly^(^)^);
echo.
echo         base.OnModelCreating^(modelBuilder^);
echo     }
echo.
echo     public override async Task^<int^> SaveChangesAsync^(CancellationToken cancellationToken = default^)
echo     {
echo         // Aquí se pueden interceptar eventos antes de guardar
echo         return await base.SaveChangesAsync^(cancellationToken^);
echo     }
echo }
) > "%projectName%.Infrastructure\Adapters\Persistence\ApplicationDbContext.cs"

echo.
echo [INFO] Creando Repositorios (Adaptadores de Persistencia)...

REM ========== REPOSITORIES ==========

(
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo.
echo namespace %projectName%.Infrastructure.Adapters.Persistence.Repositories;
echo.
echo /// ^<summary^>
echo /// Implementación del repositorio de productos
echo /// ^</summary^>
echo public class ProductRepository : IProductRepository
echo {
echo     private readonly ApplicationDbContext _context;
echo     private readonly DbSet^<Product^> _products;
echo.
echo     public ProductRepository^(ApplicationDbContext context^)
echo     {
echo         _context = context;
echo         _products = context.Set^<Product^>^(^);
echo     }
echo.
echo     public async Task^<Product?^> GetByIdAsync^(ProductId id, CancellationToken ct = default^)
echo     {
echo         return await _products.FindAsync^(new object[] { id }, ct^);
echo     }
echo.
echo     public async Task^<IEnumerable^<Product^>^> GetAllAsync^(CancellationToken ct = default^)
echo     {
echo         return await _products.ToListAsync^(ct^);
echo     }
echo.
echo     public async Task^<IEnumerable^<Product^>^> FindAsync^(
echo         ISpecification^<Product^> specification,
echo         CancellationToken ct = default^)
echo     {
echo         return await _products
echo             .Where^(specification.ToExpression^(^)^)
echo             .ToListAsync^(ct^);
echo     }
echo.
echo     public async Task^<Product^> AddAsync^(Product product, CancellationToken ct = default^)
echo     {
echo         await _products.AddAsync^(product, ct^);
echo         return product;
echo     }
echo.
echo     public Task UpdateAsync^(Product product, CancellationToken ct = default^)
echo     {
echo         _context.Entry^(product^).State = EntityState.Modified;
echo         return Task.CompletedTask;
echo     }
echo.
echo     public Task DeleteAsync^(Product product, CancellationToken ct = default^)
echo     {
echo         _products.Remove^(product^);
echo         return Task.CompletedTask;
echo     }
echo.
echo     public async Task^<bool^> ExistsAsync^(ProductId id, CancellationToken ct = default^)
echo     {
echo         return await _products.AnyAsync^(p =^> p.Id == id, ct^);
echo     }
echo }
) > "%projectName%.Infrastructure\Adapters\Persistence\Repositories\ProductRepository.cs"

(
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo.
echo namespace %projectName%.Infrastructure.Adapters.Persistence.Repositories;
echo.
echo /// ^<summary^>
echo /// Implementación del repositorio de clientes
echo /// ^</summary^>
echo public class CustomerRepository : ICustomerRepository
echo {
echo     private readonly ApplicationDbContext _context;
echo     private readonly DbSet^<Customer^> _customers;
echo.
echo     public CustomerRepository^(ApplicationDbContext context^)
echo     {
echo         _context = context;
echo         _customers = context.Set^<Customer^>^(^);
echo     }
echo.
echo     public async Task^<Customer?^> GetByIdAsync^(CustomerId id, CancellationToken ct = default^)
echo     {
echo         return await _customers.FindAsync^(new object[] { id }, ct^);
echo     }
echo.
echo     public async Task^<IEnumerable^<Customer^>^> GetAllAsync^(CancellationToken ct = default^)
echo     {
echo         return await _customers.ToListAsync^(ct^);
echo     }
echo.
echo     public async Task^<IEnumerable^<Customer^>^> FindAsync^(
echo         ISpecification^<Customer^> specification,
echo         CancellationToken ct = default^)
echo     {
echo         return await _customers
echo             .Where^(specification.ToExpression^(^)^)
echo             .ToListAsync^(ct^);
echo     }
echo.
echo     public async Task^<Customer^> AddAsync^(Customer customer, CancellationToken ct = default^)
echo     {
echo         await _customers.AddAsync^(customer, ct^);
echo         return customer;
echo     }
echo.
echo     public Task UpdateAsync^(Customer customer, CancellationToken ct = default^)
echo     {
echo         _context.Entry^(customer^).State = EntityState.Modified;
echo         return Task.CompletedTask;
echo     }
echo.
echo     public Task DeleteAsync^(Customer customer, CancellationToken ct = default^)
echo     {
echo         _customers.Remove^(customer^);
echo         return Task.CompletedTask;
echo     }
echo.
echo     public async Task^<bool^> ExistsAsync^(CustomerId id, CancellationToken ct = default^)
echo     {
echo         return await _customers.AnyAsync^(c =^> c.Id == id, ct^);
echo     }
echo.
echo     public async Task^<Customer?^> GetByEmailAsync^(string email, CancellationToken ct = default^)
echo     {
echo         return await _customers
echo             .FirstOrDefaultAsync^(c =^> c.Email.Address == email.ToLower^(^), ct^);
echo     }
echo }
) > "%projectName%.Infrastructure\Adapters\Persistence\Repositories\CustomerRepository.cs"

(
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo.
echo namespace %projectName%.Infrastructure.Adapters.Persistence.Repositories;
echo.
echo /// ^<summary^>
echo /// Implementación del repositorio de órdenes
echo /// ^</summary^>
echo public class OrderRepository : IOrderRepository
echo {
echo     private readonly ApplicationDbContext _context;
echo     private readonly DbSet^<Order^> _orders;
echo.
echo     public OrderRepository^(ApplicationDbContext context^)
echo     {
echo         _context = context;
echo         _orders = context.Set^<Order^>^(^);
echo     }
echo.
echo     public async Task^<Order?^> GetByIdAsync^(OrderId id, CancellationToken ct = default^)
echo     {
echo         return await _orders.FindAsync^(new object[] { id }, ct^);
echo     }
echo.
echo     public async Task^<IEnumerable^<Order^>^> GetAllAsync^(CancellationToken ct = default^)
echo     {
echo         return await _orders.ToListAsync^(ct^);
echo     }
echo.
echo     public async Task^<IEnumerable^<Order^>^> FindAsync^(
echo         ISpecification^<Order^> specification,
echo         CancellationToken ct = default^)
echo     {
echo         return await _orders
echo             .Where^(specification.ToExpression^(^)^)
echo             .ToListAsync^(ct^);
echo     }
echo.
echo     public async Task^<Order^> AddAsync^(Order order, CancellationToken ct = default^)
echo     {
echo         await _orders.AddAsync^(order, ct^);
echo         return order;
echo     }
echo.
echo     public Task UpdateAsync^(Order order, CancellationToken ct = default^)
echo     {
echo         _context.Entry^(order^).State = EntityState.Modified;
echo         return Task.CompletedTask;
echo     }
echo.
echo     public Task DeleteAsync^(Order order, CancellationToken ct = default^)
echo     {
echo         _orders.Remove^(order^);
echo         return Task.CompletedTask;
echo     }
echo.
echo     public async Task^<IEnumerable^<Order^>^> GetByCustomerIdAsync^(
echo         CustomerId customerId,
echo         CancellationToken ct = default^)
echo     {
echo         return await _orders
echo             .Where^(o =^> o.CustomerId == customerId^)
echo             .ToListAsync^(ct^);
echo     }
echo }
) > "%projectName%.Infrastructure\Adapters\Persistence\Repositories\OrderRepository.cs"

echo.
echo [INFO] Creando Unit of Work...

REM ========== UNIT OF WORK ==========

(
echo using Microsoft.EntityFrameworkCore.Storage;
echo using %projectName%.Application.Ports.Output;
echo.
echo namespace %projectName%.Infrastructure.Adapters.Persistence;
echo.
echo /// ^<summary^>
echo /// Implementación del patrón Unit of Work
echo /// ^</summary^>
echo public class UnitOfWork : IUnitOfWork
echo {
echo     private readonly ApplicationDbContext _context;
echo     private IDbContextTransaction? _currentTransaction;
echo.
echo     public UnitOfWork^(ApplicationDbContext context^)
echo     {
echo         _context = context;
echo     }
echo.
echo     public async Task^<int^> SaveChangesAsync^(CancellationToken ct = default^)
echo     {
echo         return await _context.SaveChangesAsync^(ct^);
echo     }
echo.
echo     public async Task BeginTransactionAsync^(CancellationToken ct = default^)
echo     {
echo         if ^(_currentTransaction != null^)
echo         {
echo             throw new InvalidOperationException^("A transaction is already in progress"^);
echo         }
echo.
echo         _currentTransaction = await _context.Database.BeginTransactionAsync^(ct^);
echo     }
echo.
echo     public async Task CommitTransactionAsync^(CancellationToken ct = default^)
echo     {
echo         if ^(_currentTransaction == null^)
echo         {
echo             throw new InvalidOperationException^("No transaction in progress"^);
echo         }
echo.
echo         try
echo         {
echo             await _context.SaveChangesAsync^(ct^);
echo             await _currentTransaction.CommitAsync^(ct^);
echo         }
echo         catch
echo         {
echo             await RollbackTransactionAsync^(ct^);
echo             throw;
echo         }
echo         finally
echo         {
echo             if ^(_currentTransaction != null^)
echo             {
echo                 await _currentTransaction.DisposeAsync^(^);
echo                 _currentTransaction = null;
echo             }
echo         }
echo     }
echo.
echo     public async Task RollbackTransactionAsync^(CancellationToken ct = default^)
echo     {
echo         if ^(_currentTransaction == null^)
echo         {
echo             throw new InvalidOperationException^("No transaction in progress"^);
echo         }
echo.
echo         try
echo         {
echo             await _currentTransaction.RollbackAsync^(ct^);
echo         }
echo         finally
echo         {
echo             if ^(_currentTransaction != null^)
echo             {
echo                 await _currentTransaction.DisposeAsync^(^);
echo                 _currentTransaction = null;
echo             }
echo         }
echo     }
echo }
) > "%projectName%.Infrastructure\Adapters\Persistence\UnitOfWork.cs"
echo.
echo [OK] Infrastructure Layer - Persistencia creada
echo.
REM ============================================================
REM === PARTE 7: EVENT SOURCING ^& INFRASTRUCTURE SERVICES ===
REM ============================================================
echo.
echo [INFO] Creando Event Store...
REM ========== EVENT STORE MODELS ==========
(
echo namespace %projectName%.Infrastructure.Adapters.EventSourcing;
echo.
echo /// ^<summary^>
echo /// Modelo de persistencia para eventos de dominio
echo /// ^</summary^>
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
echo     public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
echo }
) > "%projectName%.Infrastructure\Adapters\EventSourcing\StoredEvent.cs"
(
echo using Microsoft.EntityFrameworkCore;
echo.
echo namespace %projectName%.Infrastructure.Adapters.EventSourcing;
echo.
echo /// ^<summary^>
echo /// Contexto de base de datos para Event Store
echo /// ^</summary^>
echo public class EventStoreDbContext : DbContext
echo {
echo     public DbSet^<StoredEvent^> Events { get; set; } = null!;
echo.
echo     public EventStoreDbContext^(DbContextOptions^<EventStoreDbContext^> options^)
echo         : base^(options^)
echo     {
echo     }
echo.
echo     protected override void OnModelCreating^(ModelBuilder modelBuilder^)
echo     {
echo         modelBuilder.Entity^<StoredEvent^>^(entity =^>
echo         {
echo             entity.ToTable^("DomainEvents"^);
echo             entity.HasKey^(e =^> e.Id^);
echo             entity.Property^(e =^> e.Id^)
echo                 .ValueGeneratedOnAdd^(^);
echo.
echo             entity.Property^(e =^> e.EventId^)
echo                 .IsRequired^(^);
echo.
echo             entity.Property^(e =^> e.AggregateType^)
echo                 .IsRequired^(^)
echo                 .HasMaxLength^(200^);
echo.
echo             entity.Property^(e =^> e.AggregateId^)
echo                 .IsRequired^(^);
echo.
echo             entity.Property^(e =^> e.EventType^)
echo                 .IsRequired^(^)
echo                 .HasMaxLength^(200^);
echo.
echo             entity.Property^(e =^> e.EventData^)
echo                 .IsRequired^(^)
echo                 .HasColumnType^("nvarchar(max)"^);
echo.
echo             entity.Property^(e =^> e.OccurredOn^)
echo                 .IsRequired^(^);
echo.
echo             entity.Property^(e =^> e.Version^)
echo                 .IsRequired^(^);
echo.
echo             entity.Property^(e =^> e.CreatedAt^)
echo                 .IsRequired^(^)
echo                 .HasDefaultValueSql^("GETUTCDATE()"^);
echo.
echo             // Índices para optimizar consultas
echo             entity.HasIndex^(e =^> e.EventId^).IsUnique^(^);
echo             entity.HasIndex^(e =^> new { e.AggregateType, e.AggregateId }^);
echo             entity.HasIndex^(e =^> e.OccurredOn^);
echo             entity.HasIndex^(e =^> e.EventType^);
echo         }^);
echo.
echo         base.OnModelCreating^(modelBuilder^);
echo     }
echo }
) > "%projectName%.Infrastructure\Adapters\EventSourcing\EventStoreDbContext.cs"

(
echo using Microsoft.EntityFrameworkCore;
echo using Newtonsoft.Json;
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Domain.Common;
echo.
echo namespace %projectName%.Infrastructure.Adapters.EventSourcing;
echo.
echo /// ^<summary^>
echo /// Implementación del Event Store
echo /// ^</summary^>
echo public class EventStore : IEventStore
echo {
echo     private readonly EventStoreDbContext _context;
echo.
echo     public EventStore^(EventStoreDbContext context^)
echo     {
echo         _context = context;
echo     }
echo.
echo     public async Task SaveEventAsync^(
echo         IDomainEvent domainEvent,
echo         string aggregateType,
echo         int aggregateId,
echo         int version,
echo         CancellationToken ct = default^)
echo     {
echo         var storedEvent = new StoredEvent
echo         {
echo             EventId = domainEvent.EventId,
echo             AggregateType = aggregateType,
echo             AggregateId = aggregateId,
echo             EventType = domainEvent.GetType^(^).Name,
echo             EventData = SerializeEvent^(domainEvent^),
echo             OccurredOn = domainEvent.OccurredOn,
echo             Version = version
echo         };
echo.
echo         await _context.Events.AddAsync^(storedEvent, ct^);
echo         await _context.SaveChangesAsync^(ct^);
echo     }
echo.
echo     public async Task^<IEnumerable^<IDomainEvent^>^> GetEventsAsync^(
echo         string aggregateType,
echo         int aggregateId,
echo         CancellationToken ct = default^)
echo     {
echo         var storedEvents = await _context.Events
echo             .Where^(e =^> e.AggregateType == aggregateType ^&^& e.AggregateId == aggregateId^)
echo             .OrderBy^(e =^> e.Version^)
echo             .ToListAsync^(ct^);
echo.
echo         return storedEvents.Select^(DeserializeEvent^).Where^(e =^> e != null^)!;
echo     }
echo.
echo     public async Task^<IEnumerable^<IDomainEvent^>^> GetAllEventsAsync^(CancellationToken ct = default^)
echo     {
echo         var storedEvents = await _context.Events
echo             .OrderBy^(e =^> e.OccurredOn^)
echo             .ToListAsync^(ct^);
echo.
echo         return storedEvents.Select^(DeserializeEvent^).Where^(e =^> e != null^)!;
echo     }
echo.
echo     private static string SerializeEvent^(IDomainEvent domainEvent^)
echo     {
echo         return JsonConvert.SerializeObject^(domainEvent, new JsonSerializerSettings
echo         {
echo             TypeNameHandling = TypeNameHandling.All,
echo             ReferenceLoopHandling = ReferenceLoopHandling.Ignore
echo         }^);
echo     }
echo.
echo     private static IDomainEvent? DeserializeEvent^(StoredEvent storedEvent^)
echo     {
echo         try
echo         {
echo             return JsonConvert.DeserializeObject^<IDomainEvent^>^(storedEvent.EventData, new JsonSerializerSettings
echo             {
echo                 TypeNameHandling = TypeNameHandling.All
echo             }^);
echo         }
echo         catch
echo         {
echo             // Log error
echo             return null;
echo         }
echo     }
echo }
) > "%projectName%.Infrastructure\Adapters\EventSourcing\EventStore.cs"
echo.
echo [INFO] Creando Domain Event Dispatcher...
REM ========== DOMAIN EVENT DISPATCHER ==========
(
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Domain.Common;
echo using Microsoft.Extensions.Logging;
echo.
echo namespace %projectName%.Infrastructure.Adapters.Messaging;
echo.
echo /// ^<summary^>
echo /// Implementación del despachador de eventos de dominio
echo /// ^</summary^>
echo public class DomainEventDispatcher : IDomainEventDispatcher
echo {
echo     private readonly IEventStore _eventStore;
echo     private readonly ILogger^<DomainEventDispatcher^> _logger;
echo.
echo     public DomainEventDispatcher^(
echo         IEventStore eventStore,
echo         ILogger^<DomainEventDispatcher^> logger^)
echo     {
echo         _eventStore = eventStore;
echo         _logger = logger;
echo     }
echo.
echo     public async Task DispatchAsync^(IDomainEvent domainEvent, CancellationToken ct = default^)
echo     {
echo         try
echo         {
echo             _logger.LogInformation^(
echo                 "Dispatching domain event: {EventType} - {EventId}",
echo                 domainEvent.GetType^(^).Name,
echo                 domainEvent.EventId^);
echo.
echo             // Aquí se pueden agregar handlers adicionales
echo             // Por ejemplo, publicar a un bus de mensajes
echo.
echo             _logger.LogInformation^(
echo                 "Successfully dispatched domain event: {EventType}",
echo                 domainEvent.GetType^(^).Name^);
echo         }
echo         catch ^(Exception ex^)
echo         {
echo             _logger.LogError^(ex,
echo                 "Error dispatching domain event: {EventType}",
echo                 domainEvent.GetType^(^).Name^);
echo             throw;
echo         }
echo     }
echo.
echo     public async Task DispatchAsync^(
echo         IEnumerable^<IDomainEvent^> domainEvents,
echo         CancellationToken ct = default^)
echo     {
echo         foreach ^(var domainEvent in domainEvents^)
echo         {
echo             await DispatchAsync^(domainEvent, ct^);
echo         }
echo     }
echo }
) > "%projectName%.Infrastructure\Adapters\Messaging\DomainEventDispatcher.cs"
echo.
echo [INFO] Creando Event Handlers (opcional)...
REM ========== DOMAIN EVENT HANDLERS (EJEMPLO) ==========
(
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Domain.DomainEvents;
echo using Microsoft.Extensions.Logging;
echo.
echo namespace %projectName%.Infrastructure.Adapters.Messaging;
echo.
echo /// ^<summary^>
echo /// Handler de ejemplo para eventos de producto
echo /// ^</summary^>
echo public class ProductEventHandler
echo {
echo     private readonly IEventStore _eventStore;
echo     private readonly ILogger^<ProductEventHandler^> _logger;
echo.
echo     public ProductEventHandler^(
echo         IEventStore eventStore,
echo         ILogger^<ProductEventHandler^> logger^)
echo     {
echo         _eventStore = eventStore;
echo         _logger = logger;
echo     }
echo.
echo     public async Task HandleProductCreatedAsync^(
echo         ProductCreatedEvent @event,
echo         CancellationToken ct = default^)
echo     {
echo         _logger.LogInformation^(
echo             "Product created: {ProductId} - {ProductName}",
echo             @event.ProductId.Value,
echo             @event.ProductName^);
echo.
echo         // Guardar en Event Store
echo         await _eventStore.SaveEventAsync^(
echo             @event,
echo             "Product",
echo             @event.ProductId.Value,
echo             1,
echo             ct^);
echo.
echo         // Aquí se pueden agregar acciones adicionales:
echo         // - Enviar notificaciones
echo         // - Actualizar cachés
echo         // - Publicar en message bus
echo         // - Actualizar read models (CQRS)
echo     }
echo.
echo     public async Task HandleProductPriceChangedAsync^(
echo         ProductPriceChangedEvent @event,
echo         CancellationToken ct = default^)
echo     {
echo         _logger.LogInformation^(
echo             "Product price changed: {ProductId} from {OldPrice} to {NewPrice}",
echo             @event.ProductId.Value,
echo             @event.OldPrice,
echo             @event.NewPrice^);
echo.
echo         await _eventStore.SaveEventAsync^(
echo             @event,
echo             "Product",
echo             @event.ProductId.Value,
echo             1,
echo             ct^);
echo     }
echo.
echo     public async Task HandleStockChangedAsync^(
echo         StockAddedEvent @event,
echo         CancellationToken ct = default^)
echo     {
echo         _logger.LogInformation^(
echo             "Stock added: {ProductId} - Quantity: {Quantity}, New Stock: {NewStock}",
echo             @event.ProductId.Value,
echo             @event.QuantityAdded,
echo             @event.NewStock^);
echo.
echo         await _eventStore.SaveEventAsync^(
echo             @event,
echo             "Product",
echo             @event.ProductId.Value,
echo             1,
echo             ct^);
echo     }
echo }
) > "%projectName%.Infrastructure\Adapters\Messaging\ProductEventHandler.cs"

echo.
echo [INFO] Creando Infrastructure Services...

REM ========== COMMON SERVICES ==========

(
echo namespace %projectName%.Infrastructure.Common;
echo.
echo /// ^<summary^>
echo /// Servicio para obtener la fecha/hora actual
echo /// ^</summary^>
echo public interface IDateTimeProvider
echo {
echo     DateTime UtcNow { get; }
echo     DateTime Now { get; }
echo }
echo.
echo public class DateTimeProvider : IDateTimeProvider
echo {
echo     public DateTime UtcNow =^> DateTime.UtcNow;
echo     public DateTime Now =^> DateTime.Now;
echo }
) > "%projectName%.Infrastructure\Common\DateTimeProvider.cs"
echo.
echo [INFO] Creando Dependency Injection de Infrastructure...
REM ========== DEPENDENCY INJECTION ==========
(
echo using Microsoft.EntityFrameworkCore;
echo using Microsoft.Extensions.Configuration;
echo using Microsoft.Extensions.DependencyInjection;
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Infrastructure.Adapters.EventSourcing;
echo using %projectName%.Infrastructure.Adapters.Messaging;
echo using %projectName%.Infrastructure.Adapters.Persistence;
echo using %projectName%.Infrastructure.Adapters.Persistence.Repositories;
echo using %projectName%.Infrastructure.Common;
echo.
echo namespace %projectName%.Infrastructure;
echo.
echo /// ^<summary^>
echo /// Configuración de dependencias de la capa de infraestructura
echo /// ^</summary^>
echo public static class DependencyInjection
echo {
echo     public static IServiceCollection AddInfrastructure^(
echo         this IServiceCollection services,
echo         IConfiguration configuration^)
echo     {
echo         var connectionString = configuration.GetConnectionString^("DefaultConnection"^);   
echo         services.AddDbContext^<ApplicationDbContext^>^(options =^>
echo             options.UseSqlServer^(connectionString,
echo                 b =^> b.MigrationsAssembly^(typeof^(ApplicationDbContext^).Assembly.FullName^)^)^);
echo.
echo         var eventStoreConnectionString = configuration.GetConnectionString^("EventStoreConnection"^) 
echo             ?? connectionString;
echo         services.AddDbContext^<EventStoreDbContext^>^(options =^>
echo             options.UseSqlServer^(eventStoreConnectionString,
echo                 b =^> b.MigrationsAssembly^(typeof^(EventStoreDbContext^).Assembly.FullName^)^)^);
echo.
echo         services.AddScoped^<IProductRepository, ProductRepository^>^(^);
echo         services.AddScoped^<ICustomerRepository, CustomerRepository^>^(^);
echo         services.AddScoped^<IOrderRepository, OrderRepository^>^(^);
echo.
echo         services.AddScoped^<IUnitOfWork, UnitOfWork^>^(^);
echo.
echo         services.AddScoped^<IEventStore, EventStore^>^(^);
echo.
echo         services.AddScoped^<IDomainEventDispatcher, DomainEventDispatcher^>^(^);
echo.
echo         services.AddScoped^<ProductEventHandler^>^(^);
echo.
echo         services.AddSingleton^<IDateTimeProvider, DateTimeProvider^>^(^);
echo.
echo         return services;
echo     }
echo }
) > "%projectName%.Infrastructure\DependencyInjection.cs"

echo.
echo [INFO] Creando scripts de migración...

REM ========== MIGRATION HELPERS ==========

(
echo @echo off
echo echo Creando migracion de base de datos principal...
echo dotnet ef migrations add InitialCreate --project ..\%projectName%.Infrastructure --startup-project .
echo echo.
echo echo Creando migracion de Event Store...
echo dotnet ef migrations add InitialEventStore --context EventStoreDbContext --project ..\%projectName%.Infrastructure --startup-project .
echo echo.
echo echo Migraciones creadas exitosamente!
echo pause
) > "%projectName%.%uiProject%\create-migrations.bat"

(
echo @echo off
echo echo Aplicando migraciones...
echo echo.
echo echo [1/2] Aplicando migracion de base de datos principal...
echo dotnet ef database update --project ..\%projectName%.Infrastructure --startup-project .
echo echo.
echo echo [2/2] Aplicando migracion de Event Store...
echo dotnet ef database update --context EventStoreDbContext --project ..\%projectName%.Infrastructure --startup-project .
echo echo.
echo echo Migraciones aplicadas exitosamente!
echo pause
) > "%projectName%.%uiProject%\apply-migrations.bat"

echo.
echo [INFO] Creando archivo de configuración...

REM ========== APPSETTINGS.JSON ==========

(
echo {
echo   "ConnectionStrings": {
echo     "DefaultConnection": "Server=localhost;Database=%projectName%Db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true",
echo     "EventStoreConnection": "Server=localhost;Database=%projectName%EventStore;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true"
echo   },
echo   "Logging": {
echo     "LogLevel": {
echo       "Default": "Information",
echo       "Microsoft.AspNetCore": "Warning",
echo       "Microsoft.EntityFrameworkCore": "Warning"
echo     }
echo   },
echo   "AllowedHosts": "*"
echo }
) > "%projectName%.%uiProject%\appsettings.json"

(
echo {
echo   "ConnectionStrings": {
echo     "DefaultConnection": "Server=localhost;Database=%projectName%DevDb;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true",
echo     "EventStoreConnection": "Server=localhost;Database=%projectName%DevEventStore;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true"
echo   },
echo   "Logging": {
echo     "LogLevel": {
echo       "Default": "Debug",
echo       "Microsoft.AspNetCore": "Information",
echo       "Microsoft.EntityFrameworkCore": "Information"
echo     }
echo   }
echo }
) > "%projectName%.%uiProject%\appsettings.Development.json"

echo.
echo [SUCCESS] Infrastructure Layer completado!
echo.
echo Componentes creados:
echo   [+] DbContext (ApplicationDbContext)
echo   [+] Event Store (EventStoreDbContext + EventStore)
echo   [+] Repositories (ProductRepository, CustomerRepository, OrderRepository)
echo   [+] Unit of Work
echo   [+] Domain Event Dispatcher
echo   [+] Event Handlers
echo   [+] Common Services (DateTimeProvider)
echo   [+] Dependency Injection
echo   [+] Migration Scripts
echo   [+] Configuration Files
echo.
REM ============================================================
REM === PARTE 8 FINAL: API ADAPTERS ^& CONFIGURATION ===
REM ============================================================
echo.
echo ============================================================
echo === CREANDO API LAYER (ADAPTADORES PRIMARIOS) ===
echo ============================================================
REM Estructura de carpetas API
mkdir "%projectName%.%uiProject%\Controllers"
mkdir "%projectName%.%uiProject%\Middleware"
mkdir "%projectName%.%uiProject%\Filters"
mkdir "%projectName%.%uiProject%\Extensions"
echo.
echo [INFO] Creando Controllers (Adaptadores Primarios)...
REM ========== CONTROLLERS ==========
(
echo using Microsoft.AspNetCore.Mvc;
echo using %projectName%.Application.DTOs.Requests;
echo using %projectName%.Application.Ports.Input;
echo.
echo namespace %projectName%.%uiProject%.Controllers;
echo.
echo /// ^<summary^>
echo /// Controlador REST para gestión de productos
echo /// ^</summary^>
echo [ApiController]
echo [Route^("api/[controller]"^)]
echo [Produces^("application/json"^)]
echo public class ProductsController : ControllerBase
echo {
echo     private readonly IProductService _productService;
echo     private readonly ILogger^<ProductsController^> _logger;
echo.
echo     public ProductsController^(
echo         IProductService productService,
echo         ILogger^<ProductsController^> logger^)
echo     {
echo         _productService = productService;
echo         _logger = logger;
echo     }
echo.
echo     /// ^<summary^>
echo     /// Obtiene todos los productos
echo     /// ^</summary^>
echo     [HttpGet]
echo     [ProducesResponseType^(StatusCodes.Status200OK^)]
echo     public async Task^<IActionResult^> GetAll^(CancellationToken ct^)
echo     {
echo         var products = await _productService.GetAllProductsAsync^(ct^);
echo         return Ok^(products^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Obtiene un producto por ID
echo     /// ^</summary^>
echo     [HttpGet^("{id}"^)]
echo     [ProducesResponseType^(StatusCodes.Status200OK^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> GetById^(int id, CancellationToken ct^)
echo     {
echo         try
echo         {
echo             var product = await _productService.GetProductByIdAsync^(id, ct^);
echo             return Ok^(product^);
echo         }
echo         catch ^(Exception ex^) when ^(ex.Message.Contains^("not found"^)^)
echo         {
echo             return NotFound^(new { message = ex.Message }^);
echo         }
echo     }
echo.
echo     /// ^<summary^>
echo     /// Obtiene productos activos
echo     /// ^</summary^>
echo     [HttpGet^("active"^)]
echo     [ProducesResponseType^(StatusCodes.Status200OK^)]
echo     public async Task^<IActionResult^> GetActive^(CancellationToken ct^)
echo     {
echo         var products = await _productService.GetActiveProductsAsync^(ct^);
echo         return Ok^(products^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Obtiene productos en stock
echo     /// ^</summary^>
echo     [HttpGet^("in-stock"^)]
echo     [ProducesResponseType^(StatusCodes.Status200OK^)]
echo     public async Task^<IActionResult^> GetInStock^(CancellationToken ct^)
echo     {
echo         var products = await _productService.GetProductsInStockAsync^(ct^);
echo         return Ok^(products^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Obtiene productos por rango de precio
echo     /// ^</summary^>
echo     [HttpGet^("price-range"^)]
echo     [ProducesResponseType^(StatusCodes.Status200OK^)]
echo     public async Task^<IActionResult^> GetByPriceRange^(
echo         [FromQuery] decimal minPrice,
echo         [FromQuery] decimal maxPrice,
echo         CancellationToken ct^)
echo     {
echo         var products = await _productService.GetProductsByPriceRangeAsync^(minPrice, maxPrice, ct^);
echo         return Ok^(products^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Crea un nuevo producto
echo     /// ^</summary^>
echo     [HttpPost]
echo     [ProducesResponseType^(StatusCodes.Status201Created^)]
echo     [ProducesResponseType^(StatusCodes.Status400BadRequest^)]
echo     public async Task^<IActionResult^> Create^([FromBody] CreateProductRequest request, CancellationToken ct^)
echo     {
echo         var product = await _productService.CreateProductAsync^(request, ct^);
echo         return CreatedAtAction^(nameof^(GetById^), new { id = product.Id }, product^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Actualiza el precio de un producto
echo     /// ^</summary^>
echo     [HttpPut^("{id}/price"^)]
echo     [ProducesResponseType^(StatusCodes.Status204NoContent^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> UpdatePrice^(
echo         int id,
echo         [FromBody] UpdateProductPriceRequest request,
echo         CancellationToken ct^)
echo     {
echo         var result = await _productService.UpdateProductPriceAsync^(id, request.NewPrice, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Agrega stock a un producto
echo     /// ^</summary^>
echo     [HttpPost^("{id}/stock/add"^)]
echo     [ProducesResponseType^(StatusCodes.Status204NoContent^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> AddStock^(
echo         int id,
echo         [FromBody] UpdateStockRequest request,
echo         CancellationToken ct^)
echo     {
echo         var result = await _productService.AddStockAsync^(id, request.Quantity, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Remueve stock de un producto
echo     /// ^</summary^>
echo     [HttpPost^("{id}/stock/remove"^)]
echo     [ProducesResponseType^(StatusCodes.Status204NoContent^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> RemoveStock^(
echo         int id,
echo         [FromBody] UpdateStockRequest request,
echo         CancellationToken ct^)
echo     {
echo         var result = await _productService.RemoveStockAsync^(id, request.Quantity, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Desactiva un producto
echo     /// ^</summary^>
echo     [HttpPost^("{id}/deactivate"^)]
echo     [ProducesResponseType^(StatusCodes.Status204NoContent^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> Deactivate^(int id, CancellationToken ct^)
echo     {
echo         var result = await _productService.DeactivateProductAsync^(id, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Activa un producto
echo     /// ^</summary^>
echo     [HttpPost^("{id}/activate"^)]
echo     [ProducesResponseType^(StatusCodes.Status204NoContent^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> Activate^(int id, CancellationToken ct^)
echo     {
echo         var result = await _productService.ActivateProductAsync^(id, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo }
) > "%projectName%.%uiProject%\Controllers\ProductsController.cs"

(
echo using Microsoft.AspNetCore.Mvc;
echo using %projectName%.Application.DTOs.Requests;
echo using %projectName%.Application.Ports.Input;
echo.
echo namespace %projectName%.%uiProject%.Controllers;
echo.
echo /// ^<summary^>
echo /// Controlador REST para gestión de clientes
echo /// ^</summary^>
echo [ApiController]
echo [Route^("api/[controller]"^)]
echo [Produces^("application/json"^)]
echo public class CustomersController : ControllerBase
echo {
echo     private readonly ICustomerService _customerService;
echo     private readonly ILogger^<CustomersController^> _logger;
echo.
echo     public CustomersController^(
echo         ICustomerService customerService,
echo         ILogger^<CustomersController^> logger^)
echo     {
echo         _customerService = customerService;
echo         _logger = logger;
echo     }
echo.
echo     /// ^<summary^>
echo     /// Obtiene todos los clientes
echo     /// ^</summary^>
echo     [HttpGet]
echo     [ProducesResponseType^(StatusCodes.Status200OK^)]
echo     public async Task^<IActionResult^> GetAll^(CancellationToken ct^)
echo     {
echo         var customers = await _customerService.GetAllCustomersAsync^(ct^);
echo         return Ok^(customers^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Obtiene un cliente por ID
echo     /// ^</summary^>
echo     [HttpGet^("{id}"^)]
echo     [ProducesResponseType^(StatusCodes.Status200OK^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> GetById^(int id, CancellationToken ct^)
echo     {
echo         try
echo         {
echo             var customer = await _customerService.GetCustomerByIdAsync^(id, ct^);
echo             return Ok^(customer^);
echo         }
echo         catch ^(Exception ex^) when ^(ex.Message.Contains^("not found"^)^)
echo         {
echo             return NotFound^(new { message = ex.Message }^);
echo         }
echo     }
echo.
echo     /// ^<summary^>
echo     /// Obtiene clientes activos
echo     /// ^</summary^>
echo     [HttpGet^("active"^)]
echo     [ProducesResponseType^(StatusCodes.Status200OK^)]
echo     public async Task^<IActionResult^> GetActive^(CancellationToken ct^)
echo     {
echo         var customers = await _customerService.GetActiveCustomersAsync^(ct^);
echo         return Ok^(customers^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Crea un nuevo cliente
echo     /// ^</summary^>
echo     [HttpPost]
echo     [ProducesResponseType^(StatusCodes.Status201Created^)]
echo     [ProducesResponseType^(StatusCodes.Status400BadRequest^)]
echo     public async Task^<IActionResult^> Create^([FromBody] CreateCustomerRequest request, CancellationToken ct^)
echo     {
echo         var customer = await _customerService.CreateCustomerAsync^(request, ct^);
echo         return CreatedAtAction^(nameof^(GetById^), new { id = customer.Id }, customer^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Actualiza el email de un cliente
echo     /// ^</summary^>
echo     [HttpPut^("{id}/email"^)]
echo     [ProducesResponseType^(StatusCodes.Status204NoContent^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> UpdateEmail^(
echo         int id,
echo         [FromBody] UpdateCustomerEmailRequest request,
echo         CancellationToken ct^)
echo     {
echo         var result = await _customerService.UpdateCustomerEmailAsync^(id, request.NewEmail, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Desactiva un cliente
echo     /// ^</summary^>
echo     [HttpPost^("{id}/deactivate"^)]
echo     [ProducesResponseType^(StatusCodes.Status204NoContent^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> Deactivate^(int id, CancellationToken ct^)
echo     {
echo         var result = await _customerService.DeactivateCustomerAsync^(id, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo }
) > "%projectName%.%uiProject%\Controllers\CustomersController.cs"

(
echo using Microsoft.AspNetCore.Mvc;
echo using %projectName%.Application.DTOs.Requests;
echo using %projectName%.Application.Ports.Input;
echo.
echo namespace %projectName%.%uiProject%.Controllers;
echo.
echo /// ^<summary^>
echo /// Controlador REST para gestión de órdenes
echo /// ^</summary^>
echo [ApiController]
echo [Route^("api/[controller]"^)]
echo [Produces^("application/json"^)]
echo public class OrdersController : ControllerBase
echo {
echo     private readonly IOrderService _orderService;
echo     private readonly ILogger^<OrdersController^> _logger;
echo.
echo     public OrdersController^(
echo         IOrderService orderService,
echo         ILogger^<OrdersController^> logger^)
echo     {
echo         _orderService = orderService;
echo         _logger = logger;
echo     }
echo.
echo     /// ^<summary^>
echo     /// Obtiene una orden por ID
echo     /// ^</summary^>
echo     [HttpGet^("{id}"^)]
echo     [ProducesResponseType^(StatusCodes.Status200OK^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> GetById^(int id, CancellationToken ct^)
echo     {
echo         try
echo         {
echo             var order = await _orderService.GetOrderByIdAsync^(id, ct^);
echo             return Ok^(order^);
echo         }
echo         catch ^(Exception ex^) when ^(ex.Message.Contains^("not found"^)^)
echo         {
echo             return NotFound^(new { message = ex.Message }^);
echo         }
echo     }
echo.
echo     /// ^<summary^>
echo     /// Obtiene órdenes por cliente
echo     /// ^</summary^>
echo     [HttpGet^("customer/{customerId}"^)]
echo     [ProducesResponseType^(StatusCodes.Status200OK^)]
echo     public async Task^<IActionResult^> GetByCustomer^(int customerId, CancellationToken ct^)
echo     {
echo         var orders = await _orderService.GetOrdersByCustomerAsync^(customerId, ct^);
echo         return Ok^(orders^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Obtiene órdenes pendientes
echo     /// ^</summary^>
echo     [HttpGet^("pending"^)]
echo     [ProducesResponseType^(StatusCodes.Status200OK^)]
echo     public async Task^<IActionResult^> GetPending^(CancellationToken ct^)
echo     {
echo         var orders = await _orderService.GetPendingOrdersAsync^(ct^);
echo         return Ok^(orders^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Crea una nueva orden
echo     /// ^</summary^>
echo     [HttpPost]
echo     [ProducesResponseType^(StatusCodes.Status201Created^)]
echo     [ProducesResponseType^(StatusCodes.Status400BadRequest^)]
echo     public async Task^<IActionResult^> Create^([FromBody] CreateOrderRequest request, CancellationToken ct^)
echo     {
echo         var order = await _orderService.CreateOrderAsync^(request, ct^);
echo         return CreatedAtAction^(nameof^(GetById^), new { id = order.Id }, order^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Agrega un item a una orden
echo     /// ^</summary^>
echo     [HttpPost^("{id}/items"^)]
echo     [ProducesResponseType^(StatusCodes.Status204NoContent^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> AddItem^(
echo         int id,
echo         [FromBody] AddOrderItemRequest request,
echo         CancellationToken ct^)
echo     {
echo         var result = await _orderService.AddItemToOrderAsync^(id, request, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Confirma una orden
echo     /// ^</summary^>
echo     [HttpPost^("{id}/confirm"^)]
echo     [ProducesResponseType^(StatusCodes.Status204NoContent^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> Confirm^(int id, CancellationToken ct^)
echo     {
echo         var result = await _orderService.ConfirmOrderAsync^(id, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Envía una orden
echo     /// ^</summary^>
echo     [HttpPost^("{id}/ship"^)]
echo     [ProducesResponseType^(StatusCodes.Status204NoContent^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> Ship^(int id, CancellationToken ct^)
echo     {
echo         var result = await _orderService.ShipOrderAsync^(id, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Marca una orden como entregada
echo     /// ^</summary^>
echo     [HttpPost^("{id}/deliver"^)]
echo     [ProducesResponseType^(StatusCodes.Status204NoContent^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> Deliver^(int id, CancellationToken ct^)
echo     {
echo         var result = await _orderService.DeliverOrderAsync^(id, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo.
echo     /// ^<summary^>
echo     /// Cancela una orden
echo     /// ^</summary^>
echo     [HttpPost^("{id}/cancel"^)]
echo     [ProducesResponseType^(StatusCodes.Status204NoContent^)]
echo     [ProducesResponseType^(StatusCodes.Status404NotFound^)]
echo     public async Task^<IActionResult^> Cancel^(int id, CancellationToken ct^)
echo     {
echo         var result = await _orderService.CancelOrderAsync^(id, ct^);
echo         return result ? NoContent^(^) : NotFound^(^);
echo     }
echo }
) > "%projectName%.%uiProject%\Controllers\OrdersController.cs"
echo.
echo [INFO] Creando Middleware...
REM ========== MIDDLEWARE ==========
(
echo using System.Net;
echo using System.Text.Json;
echo using %projectName%.Application.Exceptions;
echo using %projectName%.Domain.Exceptions;
echo.
echo namespace %projectName%.%uiProject%.Middleware;
echo.
echo /// ^<summary^>
echo /// Middleware para manejo global de excepciones
echo /// ^</summary^>
echo public class ExceptionHandlingMiddleware
echo {
echo     private readonly RequestDelegate _next;
echo     private readonly ILogger^<ExceptionHandlingMiddleware^> _logger;
echo.
echo     public ExceptionHandlingMiddleware^(
echo         RequestDelegate next,
echo         ILogger^<ExceptionHandlingMiddleware^> logger^)
echo     {
echo         _next = next;
echo         _logger = logger;
echo     }
echo.
echo     public async Task InvokeAsync^(HttpContext context^)
echo     {
echo         try
echo         {
echo             await _next^(context^);
echo         }
echo         catch ^(Exception ex^)
echo         {
echo             await HandleExceptionAsync^(context, ex^);
echo         }
echo     }
echo.
echo     private Task HandleExceptionAsync^(HttpContext context, Exception exception^)
echo     {
echo         var response = context.Response;
echo         response.ContentType = "application/json";
echo.
echo         var ^(statusCode, message^) = exception switch
echo         {
echo             DomainException =^> ^(HttpStatusCode.BadRequest, exception.Message^),
echo             BusinessRuleException =^> ^(HttpStatusCode.BadRequest, exception.Message^),
echo             EntityNotFoundException =^> ^(HttpStatusCode.NotFound, exception.Message^),
echo             FluentValidation.ValidationException validationEx =^> ^(
echo                 HttpStatusCode.BadRequest,
echo                 string.Join^("; ", validationEx.Errors.Select^(e =^> e.ErrorMessage^)^)
echo             ^),
echo             Application.Exceptions.ValidationException appValidationEx =^> ^(
echo                 HttpStatusCode.BadRequest,
echo                 JsonSerializer.Serialize^(appValidationEx.Errors^)
echo             ^),
echo             Application.Exceptions.ApplicationException =^> ^(HttpStatusCode.BadRequest, exception.Message^),
echo             _ =^> ^(HttpStatusCode.InternalServerError, "An internal error occurred."^)
echo         };
echo.
echo         response.StatusCode = ^(int^)statusCode;
echo.
echo         if ^(statusCode == HttpStatusCode.InternalServerError^)
echo         {
echo             _logger.LogError^(exception, "An unhandled exception occurred"^);
echo         }
echo.
echo         var result = JsonSerializer.Serialize^(new
echo         {
echo             error = message,
echo             statusCode = ^(int^)statusCode
echo         }^);
echo.
echo         return response.WriteAsync^(result^);
echo     }
echo }
) > "%projectName%.%uiProject%\Middleware\ExceptionHandlingMiddleware.cs"
echo.
echo [INFO] Creando Extensions...
REM ========== EXTENSIONS ==========
(
echo namespace %projectName%.%uiProject%.Extensions;
echo.
echo /// ^<summary^>
echo /// Extensiones para servicios de Swagger
echo /// ^</summary^>
echo public static class SwaggerExtensions
echo {
echo     public static IServiceCollection AddSwaggerDocumentation^(this IServiceCollection services^)
echo     {
echo         services.AddEndpointsApiExplorer^(^);
echo         services.AddSwaggerGen^(c =^>
echo         {
echo             c.SwaggerDoc^("v1", new Microsoft.OpenApi.Models.OpenApiInfo
echo             {
echo                 Title = "%projectName% API",
echo                 Version = "v1",
echo                 Description = "API basada en Arquitectura Hexagonal con DDD",
echo                 Contact = new Microsoft.OpenApi.Models.OpenApiContact
echo                 {
echo                     Name = "Development Team"
echo                 }
echo             }^);
echo.
echo             // Incluir comentarios XML
echo             var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly^(^).GetName^(^).Name}.xml";
echo             var xmlPath = Path.Combine^(AppContext.BaseDirectory, xmlFile^);
echo             if ^(File.Exists^(xmlPath^)^)
echo             {
echo                 c.IncludeXmlComments^(xmlPath^);
echo             }
echo         }^);
echo.
echo         return services;
echo     }
echo.
echo     public static IApplicationBuilder UseSwaggerDocumentation^(this IApplicationBuilder app^)
echo     {
echo         app.UseSwagger^(^);
echo         app.UseSwaggerUI^(c =^>
echo         {
echo             c.SwaggerEndpoint^("/swagger/v1/swagger.json", "%projectName% API V1"^);
echo             c.RoutePrefix = string.Empty;
echo         }^);
echo.
echo         return app;
echo     }
echo }
) > "%projectName%.%uiProject%\Extensions\SwaggerExtensions.cs"
echo.
echo [INFO] Creando Program.cs...
REM ========== PROGRAM.CS ==========
(
echo using %projectName%.Application;
echo using %projectName%.Infrastructure;
echo using %projectName%.%uiProject%.Extensions;
echo using %projectName%.%uiProject%.Middleware;
echo.
echo var builder = WebApplication.CreateBuilder^(args^);
echo.
echo // Add services to the container
echo builder.Services.AddControllers^(^);
echo.
echo // Swagger
echo builder.Services.AddSwaggerDocumentation^(^);
echo.
echo // Application Layer
echo builder.Services.AddApplication^(^);
echo.
echo // Infrastructure Layer
echo builder.Services.AddInfrastructure^(builder.Configuration^);
echo.
echo // CORS
echo builder.Services.AddCors^(options =^>
echo {
echo     options.AddPolicy^("AllowAll", policy =^>
echo     {
echo         policy.AllowAnyOrigin^(^)
echo               .AllowAnyMethod^(^)
echo               .AllowAnyHeader^(^);
echo     }^);
echo }^);
echo.
echo var app = builder.Build^(^);
echo.
echo // Configure the HTTP request pipeline
echo if ^(app.Environment.IsDevelopment^(^)^)
echo {
echo     app.UseSwaggerDocumentation^(^);
echo }
echo.
echo app.UseHttpsRedirection^(^);
echo.
echo app.UseCors^("AllowAll"^);
echo.
echo // Exception Handling Middleware
echo app.UseMiddleware^<ExceptionHandlingMiddleware^>^(^);
echo.
echo app.UseAuthorization^(^);
echo.
echo app.MapControllers^(^);
echo.
echo app.Run^(^);
) > "%projectName%.%uiProject%\Program.cs"
echo.
echo [INFO] Actualizando archivo .csproj para XML documentation...
REM Actualizar csproj para generar XML documentation
(
echo ^<Project Sdk="Microsoft.NET.Sdk.Web"^>
echo   ^<PropertyGroup^>
echo     ^<TargetFramework^>net8.0^</TargetFramework^>
echo     ^<Nullable^>enable^</Nullable^>
echo     ^<ImplicitUsings^>enable^</ImplicitUsings^>
echo     ^<GenerateDocumentationFile^>true^</GenerateDocumentationFile^>
echo     ^<NoWarn^>$^(NoWarn^);1591^</NoWarn^>
echo   ^</PropertyGroup^>
echo.
echo   ^<ItemGroup^>
echo     ^<ProjectReference Include="..\%projectName%.Application\%projectName%.Application.csproj" /^>
echo     ^<ProjectReference Include="..\%projectName%.Infrastructure\%projectName%.Infrastructure.csproj" /^>
echo   ^</ItemGroup^>
echo.
echo   ^<ItemGroup^>
echo     ^<PackageReference Include="MediatR" Version="12.2.0" /^>
echo     ^<PackageReference Include="Swashbuckle.AspNetCore" Version="6.5.0" /^>
echo   ^</ItemGroup^>
echo ^</Project^>
) > "%projectName%.%uiProject%\%projectName%.%uiProject%.csproj"
echo.
echo [INFO] Agregando referencias entre proyectos...

cd "%projectName%.Application"
dotnet add reference "..\%projectName%.Domain\%projectName%.Domain.csproj"
cd ..

cd "%projectName%.Infrastructure"
dotnet add reference "..\%projectName%.Domain\%projectName%.Domain.csproj"
dotnet add reference "..\%projectName%.Application\%projectName%.Application.csproj"
cd ..

cd "%projectName%.%uiProject%"
dotnet add reference "..\%projectName%.Application\%projectName%.Application.csproj"
dotnet add reference "..\%projectName%.Infrastructure\%projectName%.Infrastructure.csproj"
cd ..

echo.
echo [INFO] Creando Docker Compose...

REM ========== DOCKER COMPOSE ==========

(
echo version: '3.8'
echo.
echo services:
echo   sqlserver:
echo     image: mcr.microsoft.com/mssql/server:2022-latest
echo     container_name: %projectName%-sqlserver
echo     environment:
echo       - ACCEPT_EULA=Y
echo       - SA_PASSWORD=YourStrong@Passw0rd
echo       - MSSQL_PID=Developer
echo     ports:
echo       - "1433:1433"
echo     volumes:
echo       - sqlserver-data:/var/opt/mssql
echo     networks:
echo       - %projectName%-network
echo.
echo   api:
echo     build:
echo       context: .
echo       dockerfile: src/%projectName%.%uiProject%/Dockerfile
echo     container_name: %projectName%-api
echo     environment:
echo       - ASPNETCORE_ENVIRONMENT=Development
echo       - ASPNETCORE_URLS=http://+:80
echo       - ConnectionStrings__DefaultConnection=Server=sqlserver;Database=%projectName%Db;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True
echo       - ConnectionStrings__EventStoreConnection=Server=sqlserver;Database=%projectName%EventStore;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True
echo     ports:
echo       - "5000:80"
echo     depends_on:
echo       - sqlserver
echo     networks:
echo       - %projectName%-network
echo.
echo networks:
echo   %projectName%-network:
echo     driver: bridge
echo.
echo volumes:
echo   sqlserver-data:
) > "%projectDirectory%\docker-compose.yml"

echo.
echo [INFO] Creando Dockerfile...

(
echo FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
echo WORKDIR /app
echo EXPOSE 80
echo EXPOSE 443
echo.
echo FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
echo WORKDIR /src
echo COPY ["src/%projectName%.%uiProject%/%projectName%.%uiProject%.csproj", "src/%projectName%.%uiProject%/"]
echo COPY ["src/%projectName%.Application/%projectName%.Application.csproj", "src/%projectName%.Application/"]
echo COPY ["src/%projectName%.Domain/%projectName%.Domain.csproj", "src/%projectName%.Domain/"]
echo COPY ["src/%projectName%.Infrastructure/%projectName%.Infrastructure.csproj", "src/%projectName%.Infrastructure/"]
echo RUN dotnet restore "src/%projectName%.%uiProject%/%projectName%.%uiProject%.csproj"
echo COPY . .
echo WORKDIR "/src/src/%projectName%.%uiProject%"
echo RUN dotnet build "%projectName%.%uiProject%.csproj" -c Release -o /app/build
echo.
echo FROM build AS publish
echo RUN dotnet publish "%projectName%.%uiProject%.csproj" -c Release -o /app/publish
echo.
echo FROM base AS final
echo WORKDIR /app
echo COPY --from=publish /app/publish .
echo ENTRYPOINT ["dotnet", "%projectName%.%uiProject%.dll"]
) > "%projectName%.%uiProject%\Dockerfile"
echo.
echo [INFO] Creando .dockerignore...
(
echo **/.classpath
echo **/.dockerignore
echo **/.env
echo **/.git
echo **/.gitignore
echo **/.project
echo **/.settings
echo **/.toolstarget
echo **/.vs
echo **/.vscode
echo **/.proj.user
echo **/.dbmdl
echo **/.jfm
echo **/bin
echo **/charts
echo */docker-compose
echo */compose
echo */Dockerfile
echo **/node_modules
echo **/npm-debug.log
echo **/obj
echo **/secrets.dev.yaml
echo **/values.dev.yaml
echo README.md
) > "%projectName%.%uiProject%.dockerignore"
echo.
echo [INFO] Creando documentación...
REM ========== DOCUMENTATION ==========
(
echo # %projectName%
echo.
echo ## Arquitectura Hexagonal - Ports and Adapters + DDD
echo.
echo Este proyecto implementa una arquitectura hexagonal completa con Domain-Driven Design.
echo.
echo ### Estructura del Proyecto
echo.
echo ```
echo %projectName%/
echo +-- src/
echo ^|   +-- %projectName%.Domain/              # Nucleo del hexagono
echo ^|   ^|   +-- Aggregates/                    # Agregados
echo ^|   ^|   +-- Entities/                      # Entidades
echo ^|   ^|   +-- ValueObjects/                  # Value Objects
echo ^|   ^|   +-- DomainEvents/                  # Eventos de dominio
echo ^|   ^|   +-- Specifications/                # Patron Specification
echo ^|   ^|   +-- Services/                      # Servicios de dominio
echo ^|   ^|
echo ^|   +-- %projectName%.Application/          # Casos de uso + Puertos
echo ^|   ^|   +-- Ports/Input/                   # Puertos primarios
echo ^|   ^|   +-- Ports/Output/                  # Puertos secundarios
echo ^|   ^|   +-- UseCases/                      # Implementacion de casos de uso
echo ^|   ^|   +-- DTOs/                          # Data Transfer Objects
echo ^|   ^|
echo ^|   +-- %projectName%.Infrastructure/       # Adaptadores secundarios
echo ^|   ^|   +-- Adapters/Persistence/          # EF Core + Repositorios
echo ^|   ^|   +-- Adapters/EventSourcing/        # Event Store
echo ^|   ^|
echo ^|   +-- %projectName%.API/                  # Adaptador primario REST API
echo ^|       +-- Controllers/                    # Endpoints REST
echo +-- tests/
echo +-- docs/
echo ```
echo.
echo ### Comandos Utiles
echo.
echo #### Crear Migraciones
echo ```bash
echo cd src\%projectName%.%uiProject%
echo .\create-migrations.bat
echo ```
echo.
echo #### Aplicar Migraciones
echo ```bash
echo .\apply-migrations.bat
echo ```
echo.
echo #### Ejecutar localmente
echo ```bash
echo dotnet run
echo ```
echo.
echo ### Swagger UI
echo.
echo Una vez ejecutada la aplicacion, acceder a: http://localhost:5000
echo.
echo ### Principios de Arquitectura Hexagonal
echo.
echo 1. Nucleo del Dominio - Independiente de frameworks
echo 2. Puertos - Interfaces que definen contratos
echo 3. Adaptadores - Implementaciones concretas
echo 4. Inversion de dependencias - El nucleo no conoce la infraestructura
echo.
echo ### Endpoints Disponibles
echo.
echo - GET /api/products - Listar todos los productos
echo - POST /api/products - Crear producto
echo - GET /api/customers - Listar clientes
echo - POST /api/orders - Crear orden
echo.
echo ### Licencia
echo.
echo MIT
) > "%projectDirectory%\docs\README.md"
(
echo # Guia de Arquitectura Hexagonal
echo.
echo ## Que es Arquitectura Hexagonal?
echo.
echo La Arquitectura Hexagonal fue propuesta por Alistair Cockburn.
echo.
echo ### Principios Clave
echo.
echo 1. El dominio es el centro - La logica de negocio no depende de nada externo
echo 2. Puertos - Interfaces que definen contratos
echo 3. Adaptadores - Implementaciones concretas de los puertos
echo 4. Inversion de dependencias - El nucleo no conoce la infraestructura
echo.
echo ### Capas
echo.
echo #### Domain - Centro del Hexagono
echo - NO depende de nada
echo - Contiene Aggregates, Entities, Value Objects
echo - Define las reglas de negocio
echo.
echo #### Application - Casos de Uso
echo - Define Puertos interfaces
echo - Implementa Casos de Uso
echo - Orquesta el dominio
echo.
echo #### Infrastructure - Adaptadores
echo - Implementa los Puertos Secundarios
echo - EF Core, APIs externas
echo.
echo #### API - Adaptador Primario
echo - Controllers REST
echo - Usa los Puertos Primarios
echo.
echo ### Beneficios
echo.
echo - Testeable - mock de adaptadores
echo - Flexible - cambiar DB sin tocar dominio
echo - Mantenible - separacion clara
echo - Independiente de frameworks
) > "%projectDirectory%\docs\ARCHITECTURE.md"
echo.
REM ============================================================
REM === PARTE 9: TESTS LAYER (UNIT TESTS) ===
REM ============================================================

echo.
echo ============================================================
echo === CREANDO TEST PROJECTS ===
echo ============================================================

cd "%projectDirectory%\tests"

echo.
echo [INFO] Creando proyectos de pruebas...

REM Crear proyectos de tests
dotnet new xunit -o "%projectName%.Domain.Tests"
dotnet new xunit -o "%projectName%.Application.Tests"
dotnet new xunit -o "%projectName%.Infrastructure.Tests"

REM Agregar proyectos al solution
cd "%projectDirectory%\src"
dotnet sln add "..\tests\%projectName%.Domain.Tests\%projectName%.Domain.Tests.csproj"
dotnet sln add "..\tests\%projectName%.Application.Tests\%projectName%.Application.Tests.csproj"
dotnet sln add "..\tests\%projectName%.Infrastructure.Tests\%projectName%.Infrastructure.Tests.csproj"

echo.
echo [INFO] Instalando paquetes NuGet para tests...

REM Domain.Tests packages
cd "%projectDirectory%\tests\%projectName%.Domain.Tests"
dotnet add reference "..\..\src\%projectName%.Domain\%projectName%.Domain.csproj"
dotnet add package FluentAssertions
dotnet add package xunit
dotnet add package xunit.runner.visualstudio
dotnet add package coverlet.collector
dotnet restore

REM Application.Tests packages
cd "%projectDirectory%\tests\%projectName%.Application.Tests"
dotnet add reference "..\..\src\%projectName%.Application\%projectName%.Application.csproj"
dotnet add reference "..\..\src\%projectName%.Domain\%projectName%.Domain.csproj"
dotnet add package FluentAssertions
dotnet add package Moq
dotnet add package xunit
dotnet add package xunit.runner.visualstudio
dotnet add package coverlet.collector
dotnet restore

REM Infrastructure.Tests packages
cd "%projectDirectory%\tests\%projectName%.Infrastructure.Tests"
dotnet add reference "..\..\src\%projectName%.Infrastructure\%projectName%.Infrastructure.csproj"
dotnet add reference "..\..\src\%projectName%.Application\%projectName%.Application.csproj"
dotnet add reference "..\..\src\%projectName%.Domain\%projectName%.Domain.csproj"
dotnet add package FluentAssertions
dotnet add package Moq
dotnet add package Microsoft.EntityFrameworkCore.InMemory
dotnet add package xunit
dotnet add package xunit.runner.visualstudio
dotnet add package coverlet.collector
dotnet restore

echo.
echo ============================================================
echo === CREANDO DOMAIN TESTS ===
echo ============================================================

cd "%projectDirectory%\tests\%projectName%.Domain.Tests"

REM Estructura de carpetas
mkdir "Aggregates"
mkdir "ValueObjects"
mkdir "Specifications"

echo.
echo [INFO] Creando tests para Aggregates...

REM ========== PRODUCT TESTS ==========
(
echo using FluentAssertions;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Domain.Tests.Aggregates;
echo.
echo public class ProductTests
echo {
echo     [Fact]
echo     public void Create_WithValidData_ShouldCreateProduct^(^)
echo     {
echo         // Arrange
echo         var id = ProductId.Create^(^);
echo         var name = "Test Product";
echo         var price = Money.Create^(100, "USD"^);
echo         var description = "Test Description";
echo         var stock = 10;
echo.
echo         // Act
echo         var product = Product.Create^(id, name, price, description, stock^);
echo.
echo         // Assert
echo         product.Should^(^).NotBeNull^(^);
echo         product.Name.Should^(^).Be^(name^);
echo         product.Price.Should^(^).Be^(price^);
echo         product.Description.Should^(^).Be^(description^);
echo         product.Stock.Should^(^).Be^(stock^);
echo         product.IsActive.Should^(^).BeTrue^(^);
echo     }
echo.
echo     [Fact]
echo     public void Create_WithEmptyName_ShouldThrowException^(^)
echo     {
echo         // Arrange
echo         var id = ProductId.Create^(^);
echo         var price = Money.Create^(100, "USD"^);
echo.
echo         // Act
echo         Action act = ^(^) =^> Product.Create^(id, "", price, "Description", 10^);
echo.
echo         // Assert
echo         act.Should^(^).Throw^<DomainException^>^(^)
echo             .WithMessage^("*name*"^);
echo     }
echo.
echo     [Fact]
echo     public void UpdatePrice_WithValidPrice_ShouldUpdateAndRaiseEvent^(^)
echo     {
echo         // Arrange
echo         var product = CreateTestProduct^(^);
echo         var newPrice = Money.Create^(150, "USD"^);
echo.
echo         // Act
echo         product.UpdatePrice^(newPrice^);
echo.
echo         // Assert
echo         product.Price.Should^(^).Be^(newPrice^);
echo         product.DomainEvents.Should^(^).HaveCount^(2^); // Created + PriceChanged
echo     }
echo.
echo     [Fact]
echo     public void AddStock_WithValidQuantity_ShouldIncreaseStock^(^)
echo     {
echo         // Arrange
echo         var product = CreateTestProduct^(^);
echo         var initialStock = product.Stock;
echo         var quantityToAdd = 5;
echo.
echo         // Act
echo         product.AddStock^(quantityToAdd^);
echo.
echo         // Assert
echo         product.Stock.Should^(^).Be^(initialStock + quantityToAdd^);
echo     }
echo.
echo     [Fact]
echo     public void RemoveStock_WithSufficientStock_ShouldDecreaseStock^(^)
echo     {
echo         // Arrange
echo         var product = CreateTestProduct^(^);
echo         var quantityToRemove = 5;
echo.
echo         // Act
echo         product.RemoveStock^(quantityToRemove^);
echo.
echo         // Assert
echo         product.Stock.Should^(^).Be^(5^); // 10 - 5
echo     }
echo.
echo     [Fact]
echo     public void RemoveStock_WithInsufficientStock_ShouldThrowException^(^)
echo     {
echo         // Arrange
echo         var product = CreateTestProduct^(^);
echo.
echo         // Act
echo         Action act = ^(^) =^> product.RemoveStock^(20^);
echo.
echo         // Assert
echo         act.Should^(^).Throw^<BusinessRuleException^>^(^)
echo             .WithMessage^("*Insufficient stock*"^);
echo     }
echo.
echo     [Fact]
echo     public void Deactivate_WhenActive_ShouldDeactivateAndRaiseEvent^(^)
echo     {
echo         // Arrange
echo         var product = CreateTestProduct^(^);
echo.
echo         // Act
echo         product.Deactivate^(^);
echo.
echo         // Assert
echo         product.IsActive.Should^(^).BeFalse^(^);
echo         product.DomainEvents.Should^(^).Contain^(e =^> e.GetType^(^).Name == "ProductDeactivatedEvent"^);
echo     }
echo.
echo     private static Product CreateTestProduct^(^)
echo     {
echo         return Product.Create^(
echo             ProductId.Create^(^),
echo             "Test Product",
echo             Money.Create^(100, "USD"^),
echo             "Test Description",
echo             10
echo         ^);
echo     }
echo }
) > "Aggregates\ProductTests.cs"

REM ========== CUSTOMER TESTS ==========
(
echo using FluentAssertions;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Domain.Tests.Aggregates;
echo.
echo public class CustomerTests
echo {
echo     [Fact]
echo     public void Create_WithValidData_ShouldCreateCustomer^(^)
echo     {
echo         // Arrange
echo         var id = CustomerId.Create^(^);
echo         var firstName = "John";
echo         var lastName = "Doe";
echo         var email = Email.Create^("john.doe@example.com"^);
echo.
echo         // Act
echo         var customer = Customer.Create^(id, firstName, lastName, email^);
echo.
echo         // Assert
echo         customer.Should^(^).NotBeNull^(^);
echo         customer.FirstName.Should^(^).Be^(firstName^);
echo         customer.LastName.Should^(^).Be^(lastName^);
echo         customer.Email.Should^(^).Be^(email^);
echo         customer.IsActive.Should^(^).BeTrue^(^);
echo     }
echo.
echo     [Fact]
echo     public void GetFullName_ShouldReturnCombinedName^(^)
echo     {
echo         // Arrange
echo         var customer = CreateTestCustomer^(^);
echo.
echo         // Act
echo         var fullName = customer.GetFullName^(^);
echo.
echo         // Assert
echo         fullName.Should^(^).Be^("John Doe"^);
echo     }
echo.
echo     [Fact]
echo     public void UpdateEmail_WithValidEmail_ShouldUpdateAndRaiseEvent^(^)
echo     {
echo         // Arrange
echo         var customer = CreateTestCustomer^(^);
echo         var newEmail = Email.Create^("newemail@example.com"^);
echo.
echo         // Act
echo         customer.UpdateEmail^(newEmail^);
echo.
echo         // Assert
echo         customer.Email.Should^(^).Be^(newEmail^);
echo         customer.DomainEvents.Should^(^).HaveCount^(2^);
echo     }
echo.
echo     [Fact]
echo     public void Deactivate_WhenActive_ShouldDeactivate^(^)
echo     {
echo         // Arrange
echo         var customer = CreateTestCustomer^(^);
echo.
echo         // Act
echo         customer.Deactivate^(^);
echo.
echo         // Assert
echo         customer.IsActive.Should^(^).BeFalse^(^);
echo     }
echo.
echo     private static Customer CreateTestCustomer^(^)
echo     {
echo         return Customer.Create^(
echo             CustomerId.Create^(^),
echo             "John",
echo             "Doe",
echo             Email.Create^("john.doe@example.com"^)
echo         ^);
echo     }
echo }
) > "Aggregates\CustomerTests.cs"

REM ========== ORDER TESTS ==========
(
echo using FluentAssertions;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Domain.Tests.Aggregates;
echo.
echo public class OrderTests
echo {
echo     [Fact]
echo     public void Create_WithValidData_ShouldCreateOrder^(^)
echo     {
echo         // Arrange
echo         var orderId = OrderId.Create^(^);
echo         var customerId = CustomerId.Create^(^);
echo.
echo         // Act
echo         var order = Order.Create^(orderId, customerId^);
echo.
echo         // Assert
echo         order.Should^(^).NotBeNull^(^);
echo         order.CustomerId.Should^(^).Be^(customerId^);
echo         order.Status.Should^(^).Be^(OrderStatus.Pending^);
echo         order.Items.Should^(^).BeEmpty^(^);
echo     }
echo.
echo     [Fact]
echo     public void AddItem_WithValidData_ShouldAddItem^(^)
echo     {
echo         // Arrange
echo         var order = CreateTestOrder^(^);
echo         var productId = ProductId.Create^(^);
echo         var price = Money.Create^(100, "USD"^);
echo.
echo         // Act
echo         order.AddItem^(productId, price, 2^);
echo.
echo         // Assert
echo         order.Items.Should^(^).HaveCount^(1^);
echo         order.GetItemCount^(^).Should^(^).Be^(1^);
echo     }
echo.
echo     [Fact]
echo     public void Confirm_WhenPendingWithItems_ShouldConfirm^(^)
echo     {
echo         // Arrange
echo         var order = CreateTestOrder^(^);
echo         order.AddItem^(ProductId.Create^(^), Money.Create^(100, "USD"^), 2^);
echo.
echo         // Act
echo         order.Confirm^(^);
echo.
echo         // Assert
echo         order.Status.Should^(^).Be^(OrderStatus.Confirmed^);
echo     }
echo.
echo     [Fact]
echo     public void Confirm_WhenEmpty_ShouldThrowException^(^)
echo     {
echo         // Arrange
echo         var order = CreateTestOrder^(^);
echo.
echo         // Act
echo         Action act = ^(^) =^> order.Confirm^(^);
echo.
echo         // Assert
echo         act.Should^(^).Throw^<BusinessRuleException^>^(^)
echo             .WithMessage^("*empty order*"^);
echo     }
echo.
echo     [Fact]
echo     public void CalculateTotal_WithMultipleItems_ShouldReturnCorrectTotal^(^)
echo     {
echo         // Arrange
echo         var order = CreateTestOrder^(^);
echo         order.AddItem^(ProductId.Create^(^), Money.Create^(100, "USD"^), 2^);
echo         order.AddItem^(ProductId.Create^(^), Money.Create^(50, "USD"^), 3^);
echo.
echo         // Act
echo         var total = order.CalculateTotal^(^);
echo.
echo         // Assert
echo         total.Amount.Should^(^).Be^(350^); // ^(100*2^) + ^(50*3^)
echo     }
echo.
echo     private static Order CreateTestOrder^(^)
echo     {
echo         return Order.Create^(OrderId.Create^(^), CustomerId.Create^(^)^);
echo     }
echo }
) > "Aggregates\OrderTests.cs"

echo.
echo [INFO] Creando tests para Value Objects...

REM ========== MONEY TESTS ==========
(
echo using FluentAssertions;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Domain.Tests.ValueObjects;
echo.
echo public class MoneyTests
echo {
echo     [Fact]
echo     public void Create_WithValidAmount_ShouldCreateMoney^(^)
echo     {
echo         // Act
echo         var money = Money.Create^(100.50m, "USD"^);
echo.
echo         // Assert
echo         money.Amount.Should^(^).Be^(100.50m^);
echo         money.Currency.Should^(^).Be^("USD"^);
echo     }
echo.
echo     [Fact]
echo     public void Create_WithNegativeAmount_ShouldThrowException^(^)
echo     {
echo         // Act
echo         Action act = ^(^) =^> Money.Create^(-10, "USD"^);
echo.
echo         // Assert
echo         act.Should^(^).Throw^<DomainException^>^(^)
echo             .WithMessage^("*negative*"^);
echo     }
echo.
echo     [Fact]
echo     public void Add_WithSameCurrency_ShouldReturnSum^(^)
echo     {
echo         // Arrange
echo         var money1 = Money.Create^(100, "USD"^);
echo         var money2 = Money.Create^(50, "USD"^);
echo.
echo         // Act
echo         var result = money1.Add^(money2^);
echo.
echo         // Assert
echo         result.Amount.Should^(^).Be^(150^);
echo         result.Currency.Should^(^).Be^("USD"^);
echo     }
echo.
echo     [Fact]
echo     public void Add_WithDifferentCurrency_ShouldThrowException^(^)
echo     {
echo         // Arrange
echo         var money1 = Money.Create^(100, "USD"^);
echo         var money2 = Money.Create^(50, "EUR"^);
echo.
echo         // Act
echo         Action act = ^(^) =^> money1.Add^(money2^);
echo.
echo         // Assert
echo         act.Should^(^).Throw^<DomainException^>^(^)
echo             .WithMessage^("*different currencies*"^);
echo     }
echo.
echo     [Fact]
echo     public void Multiply_WithPositiveFactor_ShouldReturnProduct^(^)
echo     {
echo         // Arrange
echo         var money = Money.Create^(100, "USD"^);
echo.
echo         // Act
echo         var result = money.Multiply^(2.5m^);
echo.
echo         // Assert
echo         result.Amount.Should^(^).Be^(250^);
echo     }
echo.
echo     [Fact]
echo     public void Equals_WithSameAmountAndCurrency_ShouldBeEqual^(^)
echo     {
echo         // Arrange
echo         var money1 = Money.Create^(100, "USD"^);
echo         var money2 = Money.Create^(100, "USD"^);
echo.
echo         // Assert
echo         money1.Should^(^).Be^(money2^);
echo     }
echo }
) > "ValueObjects\MoneyTests.cs"

REM ========== EMAIL TESTS ==========
(
echo using FluentAssertions;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Domain.Tests.ValueObjects;
echo.
echo public class EmailTests
echo {
echo     [Theory]
echo     [InlineData^("test@example.com"^)]
echo     [InlineData^("user.name@domain.co.uk"^)]
echo     [InlineData^("user+tag@example.com"^)]
echo     public void Create_WithValidEmail_ShouldCreateEmail^(string validEmail^)
echo     {
echo         // Act
echo         var email = Email.Create^(validEmail^);
echo.
echo         // Assert
echo         email.Should^(^).NotBeNull^(^);
echo         email.Address.Should^(^).Be^(validEmail.ToLowerInvariant^(^)^);
echo     }
echo.
echo     [Theory]
echo     [InlineData^(""^)]
echo     [InlineData^("   "^)]
echo     [InlineData^("invalid-email"^)]
echo     [InlineData^("@example.com"^)]
echo     [InlineData^("user@"^)]
echo     public void Create_WithInvalidEmail_ShouldThrowException^(string invalidEmail^)
echo     {
echo         // Act
echo         Action act = ^(^) =^> Email.Create^(invalidEmail^);
echo.
echo         // Assert
echo         act.Should^(^).Throw^<DomainException^>^(^);
echo     }
echo.
echo     [Fact]
echo     public void Create_ShouldNormalizeToLowerCase^(^)
echo     {
echo         // Act
echo         var email = Email.Create^("TEST@EXAMPLE.COM"^);
echo.
echo         // Assert
echo         email.Address.Should^(^).Be^("test@example.com"^);
echo     }
echo.
echo     [Fact]
echo     public void Equals_WithSameAddress_ShouldBeEqual^(^)
echo     {
echo         // Arrange
echo         var email1 = Email.Create^("test@example.com"^);
echo         var email2 = Email.Create^("test@example.com"^);
echo.
echo         // Assert
echo         email1.Should^(^).Be^(email2^);
echo     }
echo }
) > "ValueObjects\EmailTests.cs"

REM ========== ADDRESS TESTS ==========
(
echo using FluentAssertions;
echo using %projectName%.Domain.Exceptions;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Domain.Tests.ValueObjects;
echo.
echo public class AddressTests
echo {
echo     [Fact]
echo     public void Create_WithValidData_ShouldCreateAddress^(^)
echo     {
echo         // Act
echo         var address = Address.Create^(
echo             "123 Main St",
echo             "New York",
echo             "NY",
echo             "10001",
echo             "USA"
echo         ^);
echo.
echo         // Assert
echo         address.Should^(^).NotBeNull^(^);
echo         address.Street.Should^(^).Be^("123 Main St"^);
echo         address.City.Should^(^).Be^("New York"^);
echo         address.State.Should^(^).Be^("NY"^);
echo         address.ZipCode.Should^(^).Be^("10001"^);
echo         address.Country.Should^(^).Be^("USA"^);
echo     }
echo.
echo     [Fact]
echo     public void Create_WithEmptyStreet_ShouldThrowException^(^)
echo     {
echo         // Act
echo         Action act = ^(^) =^> Address.Create^("", "City", "State", "12345", "Country"^);
echo.
echo         // Assert
echo         act.Should^(^).Throw^<DomainException^>^(^)
echo             .WithMessage^("*Street*"^);
echo     }
echo.
echo     [Fact]
echo     public void ToString_ShouldReturnFormattedAddress^(^)
echo     {
echo         // Arrange
echo         var address = Address.Create^("123 Main St", "New York", "NY", "10001", "USA"^);
echo.
echo         // Act
echo         var result = address.ToString^(^);
echo.
echo         // Assert
echo         result.Should^(^).Contain^("123 Main St"^);
echo         result.Should^(^).Contain^("New York"^);
echo     }
echo }
) > "ValueObjects\AddressTests.cs"

echo.
echo [INFO] Creando tests para Specifications...

REM ========== SPECIFICATION TESTS ==========
(
echo using FluentAssertions;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Domain.Tests.Specifications;
echo.
echo public class SpecificationTests
echo {
echo     [Fact]
echo     public void ActiveProductsSpecification_ShouldFilterActiveProducts^(^)
echo     {
echo         // Arrange
echo         var activeProduct = CreateProduct^("Active", true^);
echo         var inactiveProduct = CreateProduct^("Inactive", false^);
echo         var spec = new ActiveProductsSpecification^(^);
echo.
echo         // Act
echo         var isActiveSatisfied = spec.IsSatisfiedBy^(activeProduct^);
echo         var isInactiveSatisfied = spec.IsSatisfiedBy^(inactiveProduct^);
echo.
echo         // Assert
echo         isActiveSatisfied.Should^(^).BeTrue^(^);
echo         isInactiveSatisfied.Should^(^).BeFalse^(^);
echo     }
echo.
echo     [Fact]
echo     public void ProductsInStockSpecification_ShouldFilterProductsWithStock^(^)
echo     {
echo         // Arrange
echo         var inStockProduct = CreateProductWithStock^(10^);
echo         var outOfStockProduct = CreateProductWithStock^(0^);
echo         var spec = new ProductsInStockSpecification^(^);
echo.
echo         // Act ^& Assert
echo         spec.IsSatisfiedBy^(inStockProduct^).Should^(^).BeTrue^(^);
echo         spec.IsSatisfiedBy^(outOfStockProduct^).Should^(^).BeFalse^(^);
echo     }
echo.
echo     [Fact]
echo     public void AndSpecification_ShouldCombineSpecifications^(^)
echo     {
echo         // Arrange
echo         var product = CreateProductWithStock^(10^);
echo         var activeSpec = new ActiveProductsSpecification^(^);
echo         var inStockSpec = new ProductsInStockSpecification^(^);
echo.
echo         // Act
echo         var combinedSpec = activeSpec.And^(inStockSpec^);
echo.
echo         // Assert
echo         combinedSpec.IsSatisfiedBy^(product^).Should^(^).BeTrue^(^);
echo     }
echo.
echo     private static Product CreateProduct^(string name, bool isActive^)
echo     {
echo         var product = Product.Create^(
echo             ProductId.Create^(^),
echo             name,
echo             Money.Create^(100, "USD"^),
echo             "Description",
echo             10
echo         ^);
echo.
echo         if ^(!isActive^)
echo         {
echo             product.Deactivate^(^);
echo         }
echo.
echo         return product;
echo     }
echo.
echo     private static Product CreateProductWithStock^(int stock^)
echo     {
echo         return Product.Create^(
echo             ProductId.Create^(^),
echo             "Product",
echo             Money.Create^(100, "USD"^),
echo             "Description",
echo             stock
echo         ^);
echo     }
echo }
) > "Specifications\SpecificationTests.cs"

echo.
echo [SUCCESS] Domain Tests creados!
echo.

echo ============================================================
echo === CREANDO APPLICATION TESTS ===
echo ============================================================

cd "%projectDirectory%\tests\%projectName%.Application.Tests"

mkdir "UseCases"

echo.
echo [INFO] Creando tests para Application Use Cases...

REM ========== PRODUCT SERVICE TESTS ==========
(
echo using FluentAssertions;
echo using Moq;
echo using %projectName%.Application.DTOs.Requests;
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Application.UseCases.Products;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Application.Tests.UseCases;
echo.
echo public class ProductServiceTests
echo {
echo     private readonly Mock^<IProductRepository^> _repositoryMock;
echo     private readonly Mock^<IUnitOfWork^> _unitOfWorkMock;
echo     private readonly Mock^<IDomainEventDispatcher^> _eventDispatcherMock;
echo     private readonly ProductService _service;
echo.
echo     public ProductServiceTests^(^)
echo     {
echo         _repositoryMock = new Mock^<IProductRepository^>^(^);
echo         _unitOfWorkMock = new Mock^<IUnitOfWork^>^(^);
echo         _eventDispatcherMock = new Mock^<IDomainEventDispatcher^>^(^);
echo.
echo         _service = new ProductService^(
echo             _repositoryMock.Object,
echo             _unitOfWorkMock.Object,
echo             _eventDispatcherMock.Object
echo         ^);
echo     }
echo.
echo     [Fact]
echo     public async Task CreateProductAsync_WithValidRequest_ShouldCreateProduct^(^)
echo     {
echo         // Arrange
echo         var request = new CreateProductRequest
echo         {
echo             Name = "Test Product",
echo             Price = 100,
echo             Currency = "USD",
echo             Description = "Test",
echo             InitialStock = 10
echo         };
echo.
echo         _repositoryMock
echo             .Setup^(r =^> r.AddAsync^(It.IsAny^<Product^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(^(Product p, CancellationToken ct^) =^> p^);
echo.
echo         // Act
echo         var result = await _service.CreateProductAsync^(request^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result.Name.Should^(^).Be^(request.Name^);
echo         _repositoryMock.Verify^(r =^> r.AddAsync^(It.IsAny^<Product^>^(^), It.IsAny^<CancellationToken^>^(^)^), Times.Once^);
echo         _unitOfWorkMock.Verify^(u =^> u.SaveChangesAsync^(It.IsAny^<CancellationToken^>^(^)^), Times.Once^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetProductByIdAsync_WhenExists_ShouldReturnProduct^(^)
echo     {
echo         // Arrange
echo         var productId = ProductId.From^(1^);
echo         var product = Product.Create^(
echo             productId,
echo             "Test Product",
echo             Money.Create^(100, "USD"^),
echo             "Description",
echo             10
echo         ^);
echo.
echo         _repositoryMock
echo             .Setup^(r =^> r.GetByIdAsync^(productId, It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(product^);
echo.
echo         // Act
echo         var result = await _service.GetProductByIdAsync^(1^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result.Name.Should^(^).Be^("Test Product"^);
echo     }
echo.
echo     [Fact] ******
echo     public async Task UpdateProductPriceAsync_WhenExists_ShouldUpdatePrice^(^)
echo     {
echo         // Arrange
echo         var productId = ProductId.From^(1^);
echo         var product = Product.Create^(
echo             productId,
echo             "Test Product",
echo             Money.Create^(100, "USD"^),
echo             "Description",
echo             10
echo         ^);
echo.
echo         _repositoryMock
echo             .Setup^(r =^> r.GetByIdAsync^(productId, It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(product^);
echo.
echo         // Act
echo         var result = await _service.UpdateProductPriceAsync^(1, 150^);
echo.
echo         // Assert
echo         result.Should^(^).BeTrue^(^);
echo         product.Price.Amount.Should^(^).Be^(150^);
echo     }
echo }
) > "UseCases\ProductServiceTests.cs"
REM ========== CUSTOMER SERVICE TESTS ==========
(
echo using FluentAssertions;
echo using Moq;
echo using %projectName%.Application.DTOs.Requests;
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Application.UseCases.Customers;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.ValueObjects;
echo using Xunit;
echo.
echo namespace %projectName%.Application.Tests.UseCases;
echo.
echo public class CustomerServiceTests
echo {
echo     private readonly Mock^<ICustomerRepository^> _repositoryMock;
echo     private readonly Mock^<IUnitOfWork^> _unitOfWorkMock;
echo     private readonly Mock^<IDomainEventDispatcher^> _eventDispatcherMock;
echo     private readonly CustomerService _service;
echo.
echo     public CustomerServiceTests^(^)
echo     {
echo         _repositoryMock = new Mock^<ICustomerRepository^>^(^);
echo         _unitOfWorkMock = new Mock^<IUnitOfWork^>^(^);
echo         _eventDispatcherMock = new Mock^<IDomainEventDispatcher^>^(^);
echo.
echo         _service = new CustomerService^(
echo             _repositoryMock.Object,
echo             _unitOfWorkMock.Object,
echo             _eventDispatcherMock.Object
echo         ^);
echo     }
echo.
echo     [Fact]
echo     public async Task CreateCustomerAsync_WithValidRequest_ShouldCreateCustomer^(^)
echo     {
echo         // Arrange
echo         var request = new CreateCustomerRequest
echo         {
echo             FirstName = "John",
echo             LastName = "Doe",
echo             Email = "john.doe@example.com"
echo         };
echo.
echo         _repositoryMock
echo             .Setup^(r =^> r.GetByEmailAsync^(It.IsAny^<string^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(^(Customer?^)null^);
echo.
echo         // Act
echo         var result = await _service.CreateCustomerAsync^(request^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result.FirstName.Should^(^).Be^(request.FirstName^);
echo         result.Email.Should^(^).Be^(request.Email.ToLower^(^)^);
echo     }
echo }
) > "UseCases\CustomerServiceTests.cs"
REM ========== ORDER SERVICE TESTS ==========
(
echo using FluentAssertions;
echo using Moq;
echo using %projectName%.Application.DTOs.Requests;
echo using %projectName%.Application.Ports.Output;
echo using %projectName%.Application.UseCases.Orders;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using Xunit;
echo.
echo namespace %projectName%.Application.Tests.UseCases;
echo.
echo public class OrderServiceTests
echo {
echo     private readonly Mock^<IOrderRepository^> _orderRepositoryMock;
echo     private readonly Mock^<ICustomerRepository^> _customerRepositoryMock;
echo     private readonly Mock^<IProductRepository^> _productRepositoryMock;
echo     private readonly Mock^<IUnitOfWork^> _unitOfWorkMock;
echo     private readonly Mock^<IDomainEventDispatcher^> _eventDispatcherMock;
echo     private readonly OrderService _service;
echo.
echo     public OrderServiceTests^(^)
echo     {
echo         _orderRepositoryMock = new Mock^<IOrderRepository^>^(^);
echo         _customerRepositoryMock = new Mock^<ICustomerRepository^>^(^);
echo         _productRepositoryMock = new Mock^<IProductRepository^>^(^);
echo         _unitOfWorkMock = new Mock^<IUnitOfWork^>^(^);
echo         _eventDispatcherMock = new Mock^<IDomainEventDispatcher^>^(^);
echo.
echo         _service = new OrderService^(
echo             _orderRepositoryMock.Object,
echo             _customerRepositoryMock.Object,
echo             _productRepositoryMock.Object,
echo             _unitOfWorkMock.Object,
echo             _eventDispatcherMock.Object
echo         ^);
echo     }
echo.
echo     [Fact]
echo     public async Task CreateOrderAsync_WithValidCustomer_ShouldCreateOrder^(^)
echo     {
echo         // Arrange
echo         var request = new CreateOrderRequest { CustomerId = 1 };
echo.
echo         _customerRepositoryMock
echo             .Setup^(r =^> r.ExistsAsync^(It.IsAny^<CustomerId^>^(^), It.IsAny^<CancellationToken^>^(^)^)^)
echo             .ReturnsAsync^(true^);
echo.
echo         // Act
echo         var result = await _service.CreateOrderAsync^(request^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result.CustomerId.Should^(^).Be^(1^);
echo         result.Status.Should^(^).Be^("Pending"^);
echo     }
echo }
) > "UseCases\OrderServiceTests.cs"
echo.
echo [SUCCESS] Application Tests creados!
echo.
echo ============================================================
echo === CREANDO INFRASTRUCTURE TESTS ===
echo ============================================================
cd "%projectDirectory%\tests%projectName%.Infrastructure.Tests"
mkdir "Repositories"
echo.
echo [INFO] Creando tests para Infrastructure...
REM ========== REPOSITORY TESTS ==========
(
echo using FluentAssertions;
echo using Microsoft.EntityFrameworkCore;
echo using %projectName%.Domain.Aggregates;
echo using %projectName%.Domain.Common;
echo using %projectName%.Domain.Specifications;
echo using %projectName%.Domain.ValueObjects;
echo using %projectName%.Infrastructure.Adapters.Persistence;
echo using %projectName%.Infrastructure.Adapters.Persistence.Repositories;
echo using Xunit;
echo.
echo namespace %projectName%.Infrastructure.Tests.Repositories;
echo.
echo public class RepositoryTests : IDisposable
echo {
echo     private readonly ApplicationDbContext _context;
echo     private readonly ProductRepository _repository;
echo.
echo     public RepositoryTests^(^)
echo     {
echo         var options = new DbContextOptionsBuilder^<ApplicationDbContext^>^(^)
echo             .UseInMemoryDatabase^(databaseName: Guid.NewGuid^(^).ToString^(^)^)
echo             .Options;
echo.
echo         _context = new ApplicationDbContext^(options^);
echo         _repository = new ProductRepository^(_context^);
echo     }
echo.
echo     [Fact]
echo     public async Task AddAsync_ShouldAddProductToDatabase^(^)
echo     {
echo         // Arrange
echo         var product = Product.Create^(
echo             ProductId.Create^(^),
echo             "Test Product",
echo             Money.Create^(100, "USD"^),
echo             "Description",
echo             10
echo         ^);
echo.
echo         // Act
echo         await _repository.AddAsync^(product^);
echo         await _context.SaveChangesAsync^(^);
echo.
echo         // Assert
echo         var savedProduct = await _context.Products.FirstOrDefaultAsync^(^);
echo         savedProduct.Should^(^).NotBeNull^(^);
echo         savedProduct!.Name.Should^(^).Be^("Test Product"^);
echo     }
echo.
echo     [Fact]
echo     public async Task GetByIdAsync_ShouldReturnProduct^(^)
echo     {
echo         // Arrange
echo         var product = Product.Create^(
echo             ProductId.Create^(^),
echo             "Test Product",
echo             Money.Create^(100, "USD"^),
echo             "Description",
echo             10
echo         ^);
echo.
echo         await _repository.AddAsync^(product^);
echo         await _context.SaveChangesAsync^(^);
echo.
echo         // Act
echo         var result = await _repository.GetByIdAsync^(product.Id^);
echo.
echo         // Assert
echo         result.Should^(^).NotBeNull^(^);
echo         result!.Name.Should^(^).Be^("Test Product"^);
echo     }
echo.
echo     [Fact]
echo     public async Task FindAsync_WithSpecification_ShouldReturnFilteredProducts^(^)
echo     {
echo         // Arrange
echo         var activeProduct = Product.Create^(
echo             ProductId.Create^(^),
echo             "Active Product",
echo             Money.Create^(100, "USD"^),
echo             "Description",
echo             10
echo         ^);
echo.
echo         var inactiveProduct = Product.Create^(
echo             ProductId.Create^(^),
echo             "Inactive Product",
echo             Money.Create^(50, "USD"^),
echo             "Description",
echo             5
echo         ^);
echo         inactiveProduct.Deactivate^(^);
echo.
echo         await _repository.AddAsync^(activeProduct^);
echo         await _repository.AddAsync^(inactiveProduct^);
echo         await _context.SaveChangesAsync^(^);
echo.
echo         var spec = new ActiveProductsSpecification^(^);
echo.
echo         // Act
echo         var results = await _repository.FindAsync^(spec^);
echo.
echo         // Assert
echo         results.Should^(^).HaveCount^(1^);
echo         results.First^(^).Name.Should^(^).Be^("Active Product"^);
echo     }
echo.
echo     public void Dispose^(^)
echo     {
echo         _context.Dispose^(^);
echo     }
echo }
) > "Repositories\RepositoryTests.cs"
echo.
echo [SUCCESS] Infrastructure Tests creados!
echo.
REM Crear script para ejecutar tests
(
echo @echo off
echo echo ============================================================
echo echo EJECUTANDO TESTS
echo echo ============================================================
echo echo.
echo echo [1/3] Domain Tests...
echo dotnet test ..\tests%projectName%.Domain.Tests%projectName%.Domain.Tests.csproj --logger "console;verbosity=detailed"
echo echo.
echo echo [2/3] Application Tests...
echo dotnet test ..\tests%projectName%.Application.Tests%projectName%.Application.Tests.csproj --logger "console;verbosity=detailed"
echo echo.
echo echo [3/3] Infrastructure Tests...
echo dotnet test ..\tests%projectName%.Infrastructure.Tests%projectName%.Infrastructure.Tests.csproj --logger "console;verbosity=detailed"
echo echo.
echo echo ============================================================
echo echo TESTS COMPLETADOS
echo echo ============================================================
echo pause
) > "%projectName%\run-tests.bat"
REM Crear script para coverage
(
echo @echo off
echo echo ============================================================
echo echo EJECUTANDO TESTS CON COVERAGE
echo echo ============================================================
echo dotnet test ..\tests%projectName%.Domain.Tests%projectName%.Domain.Tests.csproj /p:CollectCoverage=true /p:CoverletOutputFormat=opencover
echo dotnet test ..\tests%projectName%.Application.Tests%projectName%.Application.Tests.csproj /p:CollectCoverage=true /p:CoverletOutputFormat=opencover
echo dotnet test ..\tests%projectName%.Infrastructure.Tests%projectName%.Infrastructure.Tests.csproj /p:CollectCoverage=true /p:CoverletOutputFormat=opencover
echo echo.
echo echo Coverage reports generados!
echo pause
) > "%projectName%\run-tests-coverage.bat"
cd "%projectDirectory%\src"
echo.
echo [SUCCESS] Tests Layer completado!
echo.
echo Componentes de Test creados:
echo   [+] Domain.Tests - 9 archivos de pruebas
echo   [+] Application.Tests - 3 archivos de pruebas
echo   [+] Infrastructure.Tests - 1 archivo de pruebas
echo   [+] Scripts de ejecucion de tests
echo.
echo [SUCCESS] ¡Proyecto completado exitosamente!
echo.
echo ============================================================
echo.
echo Proyecto: %projectName%
echo Arquitectura: Hexagonal ^(Ports ^& Adapters^) + DDD
echo.
echo ============================================================
echo.
echo Estructura creada:
echo.
echo   [✓] Domain Layer - Núcleo del hexágono
echo   [✓] Application Layer - Puertos y Casos de Uso
echo   [✓] Infrastructure Layer - Adaptadores Secundarios
echo   [✓] API Layer - Adaptador Primario REST
echo   [✓] Event Sourcing - Event Store completo
echo   [✓] Docker Compose - SQL Server + API
echo   [✓] Documentación completa
echo.
echo ============================================================
echo.
echo Próximos pasos:
echo.
echo 1. Navegar al proyecto:
echo    cd %projectDirectory%
echo.
echo 2. Crear migraciones:
echo    cd src%projectName%.%uiProject%
echo    .\create-migrations.bat
echo.
echo 3. Aplicar migraciones:
echo    .\apply-migrations.bat
echo.
echo 4. Ejecutar la aplicación:
echo    dotnet run
echo.
echo 5. Acceder a Swagger:
echo    http://localhost:5000
echo.
echo O usar Docker:
echo    docker-compose up -d
echo.
echo ============================================================
echo.
echo ¡Gracias por usar el generador de arquitectura hexagonal!
echo.
pause