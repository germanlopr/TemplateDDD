@echo off
cls
color 30
echo ==================================
echo = =
echo = Creación de proyecto DDD =
echo = =
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
echo using System.Linq.Expressions;
echo namespace %projectName%.Domain.Interfaces
echo {
echo    public interface IRepository^<T^>
echo    {
echo        void Add^(T entidad^);
echo        void Delete^(int id^);
echo        void Update^(T entidad^);
echo        int Count^(Expression^<Func^<T, bool^>^> where^);
echo        T GetById^(int id^);
echo        IEnumerable^<T^> FindBy^(QueryParam^<T^> QueryParam^);
echo    }
echo }
) > "..\%projectName%.Domain\Interfaces\IRepository.cs"

(
echo using System.Linq.Expressions;
echo.
echo namespace %projectName%.Domain.Interfaces
echo {
echo     public class QueryParam^<T^>
echo     {
echo         public QueryParam^(int pag, int top^)
echo         {
echo             Pag = pag;
echo             Top = top;
echo             Where = null;
echo             OrderBy = null;
echo             OrderByDescending = null;
echo         }
echo.
echo         public int Pag { get; set; }
echo         public int Top { get; set; }
echo         public Expression^<Func^<T, bool^>^> Where { get; set; }
echo         public Func^<T, object^> OrderBy { get; set; }
echo         public Func^<T, object^> OrderByDescending { get; set; }
echo     }
echo }
) > "..\%projectName%.Domain\Interfaces\ParametrosDeQuery.cs"

mkdir ..\%projectName%.Application\Interfaces
mkdir ..\%projectName%.Application\Services
mkdir ..\%projectName%.Application\DTOs
mkdir ..\%projectName%.Application\UseCases

cd ..\..\tests

mkdir %projectName%.Domain.Tests
mkdir %projectName%.Application.Tests
mkdir %projectName%.Infrastructure.Tests
mkdir %projectName%.UIWeb.Tests

echo === Agregando referencias a proyectos ====

dotnet add ..\src\%projectName%.UIWeb reference ..\src\%projectName%.Application
dotnet add ..\src\%projectName%.UIWeb reference ..\src\%projectName%.Domain
dotnet add ..\src\%projectName%.UIWeb reference ..\src\%projectName%.Infrastructure

dotnet add ..\src\%projectName%.Application reference ..\src\%projectName%.Domain
dotnet add ..\src\%projectName%.Application reference ..\src\%projectName%.Infrastructure

dotnet add ..\src\%projectName%.Infrastructure reference ..\src\%projectName%.Domain
dotnet add ..\src\%projectName%.Infrastructure reference ..\src\%projectName%.Application

dotnet build

echo Proceso completado exitosamente.
pause