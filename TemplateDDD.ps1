Clear-Host
Write-Host "===================================" -ForegroundColor DarkGray
Write-Host "= Creación de proyecto DDD ="        -ForegroundColor Green
Write-Host "===================================" -ForegroundColor DarkGray
Write-Host ""

$projectName = Read-Host "Ingrese el nombre del proyecto"
$projectDirectory = Join-Path $PWD.Path $projectName

if (Test-Path $projectDirectory) {
    Write-Host "El directorio '$projectDirectory' ya existe. Saliendo del script."
    Pause
    Exit
}

New-Item -ItemType Directory -Path $projectDirectory | Out-Null
Set-Location $projectDirectory

dotnet new sln

$projects = "Application", "Domain.Core", "SharedKernel.Repositories", "Domain.Entities", "Infraestructure.Data", "Service", "Testing"

foreach ($project in $projects) {
    dotnet new classlib -o "$projectName.$project"
    dotnet sln add "$projectName.$project"
}

Write-Host "Ingrese el tipo de UI:"
Write-Host "1. MVC"
Write-Host "2. Blazor"
$uiType = Read-Host "Ingrese su elección (1 o 2)"

switch ($uiType) {
    '1' {
        dotnet new mvc -o "$projectName.UIWeb"
        dotnet sln add "$projectName.UIWeb"
    }
    '2' {
        dotnet new blazorserver -o "$projectName.UIWeb"
        dotnet sln add "$projectName.UIWeb"
    }
    Default {
        Write-Host "Opción no válida. Se utilizará MVC como opción predeterminada."
        dotnet new mvc -o "$projectName.UIWeb"
        dotnet sln add "$projectName.UIWeb"
    }
}

dotnet build

Set-Location "$projectDirectory\$projectName.Infraestructure.Data"

@"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net7.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="7.0.0" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="7.0.0" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="7.0.0" />
  </ItemGroup>
</Project>
"@ | Set-Content "$projectName.Infraestructure.Data.csproj"

dotnet restore

@"
using System.Linq.Expressions;
namespace $projectName.SharedKernel.Repositories
{
    public interface IRepository<T>
    {
        void Add(T entidad);
        void Delete(int id);
        void Update(T entidad);
        int Count(Expression<Func<T, bool>> where);
        T GetById(int id);
        IEnumerable<T> FindBy(QueryParam<T> QueryParam);
    }
}
"@ | Set-Content "..\$projectName.SharedKernel.Repositories\IRepository.cs"

@"
using System.Linq.Expressions;

namespace $projectName.SharedKernel.Repositories
{
     public class QueryParam<T>
     {
         public QueryParam(int pag, int top)
         {
             Pag = pag;
             Top = top;
             Where = null;
             OrderBy = null;
             OrderByDescending = null;
         }

         public int Pag { get; set; }
         public int Top { get; set; }
         public Expression<Func<T, bool>> Where { get; set; }
         public Func<T, object> OrderBy { get; set; }
         public Func<T, object> OrderByDescending { get; set; }
     }
}
"@ | Set-Content "..\$projectName.SharedKernel.Repositories\ParametrosDeQuery.cs"

@"
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using System.IO;

namespace $projectName.Infraestructure.Data
{
     public class ApplicationDbContext : DbContext
     {
         public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
             : base(options)
         {
         }

         protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
         {
             if (!optionsBuilder.IsConfigured)
             {
                 IConfigurationRoot configuration = new ConfigurationBuilder()
                     .SetBasePath(Directory.GetCurrentDirectory())
                     .AddJsonFile("appsettings.json")
                     .Build();
                 var connectionString = configuration.GetConnectionString("DefaultConnection");
                 optionsBuilder.UseSqlServer(connectionString);
             }
         }

         // Agregar DbSet<Entidad> aquí
     }
}
"@ | Set-Content "..\$projectName.Infraestructure.Data\ApplicationDbContext.cs"

Write-Host "=== Agregando referencias a proyectos ===="

dotnet add "..\$projectName.UIWeb" reference "..\$projectName.Application"
dotnet add "..\$projectName.UIWeb" reference "..\$projectName.Domain.Entities"
dotnet add "..\$projectName.UIWeb" reference "..\$projectName.Service"

dotnet add "..\$projectName.Application" reference "..\$projectName.Domain.Entities"
dotnet add "..\$projectName.Application" reference "..\$projectName.Service"
dotnet add "..\$projectName.Application" reference "..\$projectName.SharedKernel.Repositories"

dotnet add "..\$projectName.SharedKernel.Repositories" reference "..\$projectName.Domain.Entities"
dotnet add "..\$projectName.SharedKernel.Repositories" reference "..\$projectName.Service"
dotnet add "..\$projectName.SharedKernel.Repositories" reference "..\$projectName.Infraestructure.Data"

dotnet build

Write-Host "Proceso completado exitosamente."
Pause