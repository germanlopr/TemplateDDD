@echo off
set projectName=MyProject

:: Crear estructura de carpetas
mkdir ..\%projectName%.Domain\Entities
mkdir ..\%projectName%.Domain\Interfaces
mkdir ..\%projectName%.Domain\ValueObjects
mkdir ..\%projectName%.Domain\Services
mkdir ..\%projectName%.Infrastructure\Data
mkdir ..\%projectName%.Application\Services
mkdir ..\%projectName%.UIWeb

:: Crear DbContext
(
echo using Microsoft.EntityFrameworkCore;
echo namespace %projectName%.Infrastructure.Data
echo {
echo     public class ApplicationDbContext : DbContext
echo     {
echo         public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
echo             : base(options)
echo         {
echo         }
echo
echo         protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
echo         {
echo             if (!optionsBuilder.IsConfigured)
echo             {
echo                 IConfigurationRoot configuration = new ConfigurationBuilder()
echo                     .SetBasePath(Directory.GetCurrentDirectory())
echo                     .AddJsonFile("appsettings.json")
echo                     .Build();
echo                 var connectionString = configuration.GetConnectionString("DefaultConnection");
echo                 optionsBuilder.UseSqlServer(connectionString);
echo             }
echo         }
echo
echo         // Agregar DbSet<Entidad> aquí
echo     }
echo }
) > ".\\src\\%projectName%.Infrastructure\\Data\\ApplicationDbContext.cs"

:: Crear ApplicationUser
(
echo using Microsoft.AspNetCore.Identity;
echo namespace %projectName%.Infrastructure.Data
echo {
echo     public class ApplicationUser : IdentityUser
echo     {
echo     }
echo }
) > ".\\src\\%projectName%.Infrastructure\\Data\\ApplicationUser.cs"

:: Crear una entidad de ejemplo
(
echo using System;
echo namespace %projectName%.Domain.Entities
echo {
echo     public class Sample
echo     {
echo         public int Id { get; set; }
echo         public string? Name { get; set; }
echo         public DateTime CollectionDate { get; set; }
echo         public string? Status { get; set; }
echo     }
echo }
) > "..\\%projectName%.Domain\\Entities\\Sample.cs"

:: Crear un ValueObject de ejemplo
(
echo namespace %projectName%.Domain.ValueObjects
echo {
echo     using System;
echo     using System.Text.RegularExpressions;
echo
echo     public class Email
echo     {
echo         public string Address { get; private set; }
echo
echo         public Email(string address)
echo         {
echo             Address = address;
echo         }
echo     }
echo }
) > "..\\%projectName%.Domain\\ValueObjects\\Email.cs"

:: Crear una interfaz de repositorio de ejemplo
(
echo using System.Collections.Generic;
echo using %projectName%.Domain.Entities;
echo
echo namespace %projectName%.Domain.Interfaces
echo {
echo     public interface ISampleRepository
echo     {
echo         Sample GetById(int id);
echo         IEnumerable<Sample> GetAll();
echo         void Add(Sample sample);
echo         void Update(Sample sample);
echo         void Delete(int id);
echo     }
echo }
) > "..\\%projectName%.Domain\\Interfaces\\ISampleRepository.cs"

:: Crear un servicio de ejemplo
(
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.Interfaces;
echo
echo namespace %projectName%.Application.Services
echo {
echo     public class SampleService
echo     {
echo         private readonly ISampleRepository _sampleRepository;
echo
echo         public SampleService(ISampleRepository sampleRepository)
echo         {
echo             _sampleRepository = sampleRepository;
echo         }
echo
echo         public Sample GetSampleById(int id)
echo         {
echo             return _sampleRepository.GetById(id);
echo         }
echo     }
echo }
) > "..\\%projectName%.Application\\Services\\SampleService.cs"

:: Agregar configuraciones de Identity y JWT en Startup.cs
(
echo using Microsoft.AspNetCore.Authentication.JwtBearer;
echo using Microsoft.AspNetCore.Builder;
echo using Microsoft.AspNetCore.Hosting;
echo using Microsoft.AspNetCore.Identity;
echo using Microsoft.Extensions.Configuration;
echo using Microsoft.Extensions.DependencyInjection;
echo using Microsoft.Extensions.Hosting;
echo using Microsoft.IdentityModel.Tokens;
echo using Serilog;
echo using %projectName%.Infrastructure.Data;
echo using System.Text;
echo
echo namespace %projectName%.UIWeb
echo {
echo     public class Startup
echo     {
echo         public Startup(IConfiguration configuration)
echo         {
echo             Configuration = configuration;
echo         }
echo
echo         public IConfiguration Configuration { get; }
echo
echo         public void ConfigureServices(IServiceCollection services)
echo         {
echo             services.AddDbContext<ApplicationDbContext>(options =>
echo                 options.UseSqlServer(
echo                     Configuration.GetConnectionString("DefaultConnection")));
echo             services.AddDefaultIdentity<ApplicationUser>(options => options.SignIn.RequireConfirmedAccount = true)
echo                 .AddEntityFrameworkStores<ApplicationDbContext>();
echo
echo             services.AddAuthentication(options =>
echo             {
echo                 options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
echo                 options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
echo             })
echo             .AddJwtBearer(options =>
echo             {
echo                 options.TokenValidationParameters = new TokenValidationParameters
echo                 {
echo                     ValidateIssuer = true,
echo                     ValidateAudience = true,
echo                     ValidateLifetime = true,
echo                     ValidateIssuerSigningKey = true,
echo                     ValidIssuer = Configuration["Jwt:Issuer"],
echo                     ValidAudience = Configuration["Jwt:Audience"],
echo                     IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Configuration["Jwt:Key"]))
echo                 };
echo             });
echo
echo             services.AddControllersWithViews();
echo         }
echo
echo         public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
echo         {
echo             if (env.IsDevelopment())
echo             {
echo                 app.UseDeveloperExceptionPage();
echo                 app.UseSwagger();
echo                 app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "My API v1"));
echo             }
echo             else
echo             {
echo                 app.UseExceptionHandler("/Home/Error");
echo                 app.UseHsts();
echo             }
echo
echo             app.UseGlobalExceptionHandler(); // Añade esta línea
echo             app.UseSerilogRequestLogging(); // Añade esta línea
echo
echo             app.UseRouting();
echo             app.UseAuthentication();
echo             app.UseAuthorization();
echo
echo             app.UseEndpoints(endpoints =>
echo             {
echo                 endpoints.MapControllers();
echo             });
echo
echo             Log.Logger = new LoggerConfiguration()
echo                 .MinimumLevel.Debug()
echo                 .MinimumLevel.Override("Microsoft", LogEventLevel.Information)
echo                 .Enrich.FromLogContext()
echo                 .WriteTo.Console()
echo                 .CreateLogger();
echo         }
echo     }
echo }
) > ".\\src\\%projectName%.UIWeb\\Startup.cs"

:: Crear GlobalExceptionHandlerMiddleware
(
echo using Microsoft.AspNetCore.Http;
echo using Serilog;
echo using System;
echo using System.Net;
echo using System.Threading.Tasks;
echo namespace %projectName%.UIWeb
echo {
echo     public class GlobalExceptionHandlerMiddleware
echo     {
echo         private readonly RequestDelegate _next;
echo         public GlobalExceptionHandlerMiddleware(RequestDelegate next)
echo         {
echo             _next = next;
echo         }
echo
echo         public async Task InvokeAsync(HttpContext context)
echo         {
echo             try
echo             {
echo                 await _next(context);
echo             }
echo             catch (Exception ex)
echo             {
echo                 Log.Error($"Something went wrong: {ex}");
echo                 await HandleExceptionAsync(context, ex);
echo             }
echo         }
echo
echo         private Task HandleExceptionAsync(HttpContext context, Exception exception)
echo         {
echo             context.Response.ContentType = "application/json";
echo             context.Response.StatusCode = (int)HttpStatusCode.InternalServerError;
echo             return context.Response.WriteAsync(new ErrorDetails()
echo             {
echo                 StatusCode = context.Response.StatusCode,
echo                 Message = "Internal Server Error from the custom middleware."
echo             }.ToString());
echo         }
echo     }
echo
echo     public class ErrorDetails
echo     {
echo         public int StatusCode { get; set; }
echo         public string Message { get; set; }
echo         public override string ToString()
echo         {
echo             return Newtonsoft.Json.JsonConvert.SerializeObject(this);
echo         }
echo     }
echo }
) > ".\\src\\%projectName%.UIWeb\\GlobalExceptionHandlerMiddleware.cs"

:: Agregar paquetes necesarios
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore
dotnet add package Serilog.AspNetCore
dotnet add package Serilog.Sinks.Console
dotnet add package Serilog.Extensions.Logging

:: Agregar referencias a proyectos
dotnet add ..\src\%projectName%.UIWeb reference ..\src\%projectName%.Application
dotnet add ..\src\%projectName%.UIWeb reference ..\src\%projectName%.Domain
dotnet add ..\src\%projectName%.UIWeb reference ..\src\%projectName%.Infrastructure
dotnet add ..\src\%projectName%.Application reference ..\src\%projectName%.Domain
dotnet add ..\src\%projectName%.Application reference ..\src\%projectName%.Infrastructure
dotnet add ..\src\%projectName%.Infrastructure reference ..\src\%projectName%.Domain

cd ..\src\

dotnet build

echo Proceso completado exitosamente.
pause
