@echo off
cls
color 30
echo ==================================
echo =                                 =
echo =     Creación de proyecto DDD    =
echo =                                 =
echo ==================================
echo.

set /p projectName="Ingrese el nombre del proyecto: "
set projectDirectory=%cd%\%projectName%

if exist "%projectDirectory%" (
    echo El directorio "%projectDirectory%" ya existe. Saliendo del script.
    pause
    exit
)

mkdir "%projectDirectory%"
mkdir "%projectDirectory%\src"
mkdir "%projectDirectory%\tests"

cd "%projectDirectory%\src"

dotnet new sln --name %projectName%

set projects=Domain Application Infrastructure

for %%p in (%projects%) do (
    dotnet new classlib -o "%projectName%.%%p"
    dotnet sln add "%projectName%.%%p"
)

echo Ingrese el tipo de UI:
echo 1. MVC
echo 2. Blazor
set /p uiType="Ingrese su elección (1 o 2): "

if "%uiType%" == "1" (
    dotnet new mvc -o "%projectName%.UIWeb"
    dotnet sln add "%projectName%.UIWeb"
) else if "%uiType%" == "2" (
    dotnet new blazorserver -o "%projectName%.UIWeb"
    dotnet sln add "%projectName%.UIWeb"
) else (
    echo Opción no válida. Se utilizará MVC como opción predeterminada.
    dotnet new mvc -o "%projectName%.UIWeb"
    dotnet sln add "%projectName%.UIWeb"
)

dotnet build

cd "%projectDirectory%\src\%projectName%.Infrastructure"

(
echo ^<Project Sdk="Microsoft.NET.Sdk"^>
echo   ^<PropertyGroup^>
echo     ^<TargetFramework^>net7.0^</TargetFramework^>
echo   ^</PropertyGroup^>
echo   ^<ItemGroup^>
echo     ^<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="7.0.0" /^>
echo     ^<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="7.0.0" /^>
echo     ^<PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="7.0.0" /^>
echo   ^</ItemGroup^>
echo ^</Project^>
) > "%projectName%.Infrastructure.csproj"


dotnet restore

mkdir Data
mkdir Repositories
mkdir Services
mkdir Configurations

(
echo using Microsoft.EntityFrameworkCore;
echo using Microsoft.Extensions.Configuration;
echo using System.IO;
echo.
echo namespace %projectName%.Infrastructure.Data
echo {
echo     public class ApplicationDbContext : DbContext
echo     {
echo         public ApplicationDbContext^(DbContextOptions^<ApplicationDbContext^> options^)
echo             : base^(options^)
echo         {
echo         }
echo.
echo         protected override void OnConfiguring^(DbContextOptionsBuilder optionsBuilder^)
echo         {
echo             if ^(!optionsBuilder.IsConfigured^)
echo             {
echo                 IConfigurationRoot configuration = new ConfigurationBuilder^(^)
echo                     .SetBasePath^(Directory.GetCurrentDirectory^(^)^)
echo                     .AddJsonFile^("appsettings.json"^)
echo                     .Build^(^);
echo                 var connectionString = configuration.GetConnectionString^("DefaultConnection"^);
echo                 optionsBuilder.UseSqlServer^(connectionString^);
echo             }
echo         }
echo.
echo         // Agregar DbSet^<Entidad^> aquí
echo     }
echo }
) > ".\Data\ApplicationDbContext.cs"

mkdir ..\%projectName%.Domain\Entities
mkdir ..\%projectName%.Domain\Interfaces
mkdir ..\%projectName%.Domain\ValueObjects
mkdir ..\%projectName%.Domain\Services

(
echo using System;
echo.
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
) > "..\%projectName%.Domain\Entities\Sample.cs"

(
echo namespace %projectName%.Domain.ValueObjects
echo {
echo    using System;
echo    using System.Text.RegularExpressions;
echo.
echo     public class Email
echo     {
echo          public string Address { get; private set; }
echo.
echo           public Email^(string address^)
echo            {
echo            Address = address;
echo            }
echo      }
echo }
) > "..\%projectName%.Domain\ValueObjects\Email.cs"

(
echo using System.Collections.Generic;
echo using %projectName%.Domain.Entities;
echo.
echo namespace %projectName%.Domain.Interfaces
echo {
echo     public interface ISampleRepository
echo     {
echo         Sample GetById^(int id^);
echo         IEnumerable^<Sample^> GetAll^(^);
echo         void Add^(Sample sample^);
echo         void Update^(Sample sample^);
echo         void Delete^(int id^);
echo     }
echo }
) > "..\%projectName%.Domain\Interfaces\ISampleRepository.cs"

(
echo using System.Linq.Expressions;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.Interfaces;
echo.
echo namespace %projectName%.Domain.Services
echo {
echo     public class SampleService
echo     {
echo         private readonly ISampleRepository _sampleRepository;
echo.
echo         public SampleService^(ISampleRepository sampleRepository^)
echo         {
echo             _sampleRepository = sampleRepository;
echo         }
echo.
echo         public Sample GetSample^(int id^)
echo         {
echo             return _sampleRepository.GetById^(id^);
echo         }
echo.
echo         public void CreateSample^(Sample sample^)
echo         {
echo             // Add business logic here
echo             _sampleRepository.Add^(sample^);
echo         }
echo     }
echo }
) > "..\%projectName%.Domain\Services\SampleService.cs"

mkdir ..\%projectName%.Application\Interfaces
mkdir ..\%projectName%.Application\Services
mkdir ..\%projectName%.Application\DTOs
mkdir ..\%projectName%.Application\UseCases

(
echo namespace %projectName%.Application.DTOs
echo {
echo     public class SampleDto
echo     {
echo         public int Id { get; set; }
echo         public string? Name { get; set; }
echo         public DateTime CollectionDate { get; set; }
echo         public string? Status { get; set; }
echo     }
echo }
) > "..\%projectName%.Application\DTOs\SampleDto.cs"

(
echo using System.Collections.Generic;
echo using %projectName%.Application.DTOs;
echo.
echo namespace %projectName%.Application.Interfaces
echo {
echo     public interface ISampleService
echo     {
echo         SampleDto GetSample^(int id^);
echo         IEnumerable^<SampleDto^> GetAllSamples^(^);
echo         void CreateSample^(SampleDto sampleDto^);
echo         void UpdateSample^(SampleDto sampleDto^);
echo         void DeleteSample^(int id^);
echo     }
echo }
) > "..\%projectName%.Application\Interfaces\ISampleService.cs"

(
echo using System.Collections.Generic;
echo using %projectName%.Application.DTOs;
echo using %projectName%.Application.Interfaces;
echo using %projectName%.Domain.Entities;
echo using %projectName%.Domain.Interfaces;
echo.
echo namespace %projectName%.Application.Services
echo {
echo     public class SampleAppService : ISampleService
echo     {
echo         private readonly ISampleRepository _sampleRepository;
echo.
echo         public SampleAppService^(ISampleRepository sampleRepository^)
echo         {
echo             _sampleRepository = sampleRepository;
echo         }
echo.
echo         public SampleDto GetSample^(int id^)
echo         {
echo             var sample = _sampleRepository.GetById^(id^);
echo             return new SampleDto
echo             {
echo                 Id = sample.Id,
echo                 Name = sample.Name,
echo                 CollectionDate = sample.CollectionDate,
echo                 Status = sample.Status
echo             };
echo         }
echo.
echo         public IEnumerable^<SampleDto^> GetAllSamples^(^)
echo         {
echo             var samples = _sampleRepository.GetAll^(^);
echo             var sampleDtos = new List^<SampleDto^>^(^);
echo.
echo             foreach ^(var sample in samples^)
echo             {
echo                 sampleDtos.Add^(new SampleDto^(^)
echo                 {
echo                     Id = sample.Id,
echo                     Name = sample.Name,
echo                     CollectionDate = sample.CollectionDate,
echo                     Status = sample.Status
echo                 }^);
echo             }
echo.
echo             return sampleDtos;
echo         }
echo.
echo         public void CreateSample^(SampleDto sampleDto^)
echo         {
echo             var sample = new Sample
echo             {
echo                 Id = sampleDto.Id,
echo                 Name = sampleDto.Name,
echo                 CollectionDate = sampleDto.CollectionDate,
echo                 Status = sampleDto.Status
echo             };
echo.
echo             _sampleRepository.Add^(sample^);
echo         }
echo.
echo         public void UpdateSample^(SampleDto sampleDto^)
echo         {
echo             var sample = new Sample
echo             {
echo                 Id = sampleDto.Id,
echo                 Name = sampleDto.Name,
echo                 CollectionDate = sampleDto.CollectionDate,
echo                 Status = sampleDto.Status
echo             };
echo.
echo             _sampleRepository.Update^(sample^);
echo         }
echo.
echo         public void DeleteSample^(int id^)
echo         {
echo             _sampleRepository.Delete^(id^);
echo         }
echo     }
echo }
) > "..\%projectName%.Application\Services\SampleAppService.cs"

(
echo using Microsoft.AspNetCore.Mvc;
echo using %projectName%.Application.Interfaces;
echo using %projectName%.Application.DTOs;
echo.
echo namespace %projectName%.UIWeb.Controllers
echo {
echo     public class SampleController : Controller
echo     {
echo         private readonly ISampleService _sampleService;
echo.
echo         public SampleController^(ISampleService sampleService^)
echo         {
echo             _sampleService = sampleService;
echo         }
echo.
echo         public IActionResult Index^(^)
echo         {
echo             var samples = _sampleService.GetAllSamples^(^);
echo             return View^(samples^);
echo         }
echo.
echo         public IActionResult Details^(int id^)
echo         {
echo             var sample = _sampleService.GetSample^(id^);
echo             if ^(sample == null^)
echo             {
echo                 return NotFound^(^);
echo             }
echo             return View^(sample^);
echo         }
echo.
echo         public IActionResult Create^(^)
echo         {
echo             return View^(^);
echo         }
echo.
echo         [HttpPost]
echo         [ValidateAntiForgeryToken]
echo         public IActionResult Create^(SampleDto sampleDto^)
echo         {
echo             if ^(ModelState.IsValid^)
echo             {
echo                 _sampleService.CreateSample^(sampleDto^);
echo                 return RedirectToAction^(nameof^(Index^)^);
echo             }
echo             return View^(sampleDto^);
echo         }
echo     }
echo }
) > "..\%projectName%.UIWeb\Controllers\SampleController.cs"

(
echo @model IEnumerable^<%projectName%.Application.DTOs.SampleDto^>
echo.
echo ^<h1^>Samples^</h1^>
echo.
echo ^<table class="table"^>
echo     ^<thead^>
echo         ^<tr^>
echo             ^<th^>Id^</th^>
echo             ^<th^>Name^</th^>
echo             ^<th^>Collection Date^</th^>
echo             ^<th^>Status^</th^>
echo             ^<th^>Actions^</th^>
echo         ^</tr^>
echo     ^</thead^>
echo     ^<tbody^>
echo         @foreach ^(var sample in Model^)
echo         {
echo             ^<tr^>
echo                 ^<td^>@sample.Id^</td^>
echo                 ^<td^>@sample.Name^</td^>
echo                 ^<td^>@sample.CollectionDate^</td^>
echo                 ^<td^>@sample.Status^</td^>
echo                 ^<td^>
echo                     ^<a href="@Url.Action("Details", new { id = sample.Id })"^>Details^</a^>
echo                 ^</td^>
echo             ^</tr^>
echo         }
echo     ^</tbody^>
echo ^</table^>
) > "..\%projectName%.UIWeb\Views\Sample.cshtml"

cd ..\..\tests

:: Configure test projects
set testProjects=Domain.Tests Application.Tests Infrastructure.Tests UIWeb.Tests


for %%t in (%testProjects%) do (
    dotnet new xunit -o "%projectName%.%%t"
    echo %projectDirectory%\src\%projectName%.sln
    dotnet sln "%projectDirectory%\src\%projectName%.sln" add "%projectDirectory%\tests\%projectName%.%%t"
    echo %projectDirectory%\tests\%%t
)

::end test


echo === Agregando referencias a proyectos ====

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