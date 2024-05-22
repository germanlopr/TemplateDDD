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

set nombreCarpeta=%projectDirectory%

mkdir "%projectDirectory%"
cd "%projectDirectory%"

dotnet new sln

set projects=Application Domain.Core SharedKernel.Repositories Domain.Entities Infraestructure.Data Service Testing

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

cd "%projectDirectory%\%projectName%.Infraestructure.Data"

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
) > "%projectName%.Infraestructure.Data.csproj"

dotnet restore

(
echo using System.Linq.Expressions;
echo namespace %projectName%.SharedKernel.Repositories
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
) > "..\%projectName%.SharedKernel.Repositories\IRepository.cs"

(
echo using System.Linq.Expressions;
echo.
echo namespace %projectName%.SharedKernel.Repositories
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
) > "..\%projectName%.SharedKernel.Repositories\ParametrosDeQuery.cs"

(
echo using Microsoft.EntityFrameworkCore;
echo using Microsoft.Extensions.Configuration;
echo using System.IO;
echo.
echo namespace %projectName%.Infraestructure.Data
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
) > "..\%projectName%.Infraestructure.Data\ApplicationDbContext.cs"

@REM cd %nombreCarpeta%

@REM set referencias=%projectName%.UIWeb %projectName%.Application %projectName%.Domain.Entities %projectName%.Service %projectName%.SharedKernel.Repositories %projectName%.Infraestructure.Data

@REM for %%r in (%referencias%) do (
@REM     for %%p in (%referencias%) do (
@REM         if not "%%r"=="%%p" (
@REM             dotnet add "%%r" reference "%%p"
@REM         )
@REM     )
@REM )


echo === Agregando referencias a proyectos ====

dotnet add ..\%projectName%.UIWeb reference ..\%projectName%.Application
dotnet add ..\%projectName%.UIWeb reference ..\%projectName%.Domain.Entities
dotnet add ..\%projectName%.UIWeb reference ..\%projectName%.Service

dotnet add ..\%projectName%.Application reference ..\%projectName%.Domain.Entities
dotnet add ..\%projectName%.Application reference ..\%projectName%.Service
dotnet add ..\%projectName%.Application reference ..\%projectName%.SharedKernel.Repositories

dotnet add ..\%projectName%.SharedKernel.Repositories reference ..\%projectName%.Domain.Entities
dotnet add ..\%projectName%.SharedKernel.Repositories reference ..\%projectName%.Service
dotnet add ..\%projectName%.SharedKernel.Repositories reference ..\%projectName%.Infraestructure.Data

dotnet build

echo Proceso completado exitosamente.
pause