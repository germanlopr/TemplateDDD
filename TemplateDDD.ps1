Clear-Host

Write-Host "===================================="
Write-Host "=          Creación de proyecto DDD          ="
Write-Host "===================================="

$projectName = Read-Host "Ingrese el nombre del proyecto"
$projectDirectory = Join-Path $PWD.Path $projectName

if (Test-Path $projectDirectory) {
    Write-Host "El directorio '$projectDirectory' ya existe. Saliendo del script."
    Pause
    exit
}

New-Item -ItemType Directory -Path $projectDirectory | Out-Null
Set-Location $projectDirectory

dotnet new sln

$projects = @("Application", "Domain.Core", "SharedKernel.Repositories", "Domain.Entities", "Infraestructure.Data", "Service", "Testing")

foreach ($project in $projects) {
    dotnet new classlib -o "$projectName.$project"
    dotnet sln add "$projectName.$project"
}

$uiType = Read-Host "Ingrese el tipo de UI (1 = MVC, 2 = Blazor)"

switch ($uiType) {
    1 {
        dotnet new mvc -o "$projectName.UIWeb"
        dotnet sln add "$projectName.UIWeb"
    }
    2 {
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
    <TargetFramework>net6.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="6.0.16" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="6.0.16" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="6.0.0" />
  </ItemGroup>
</Project>
"@ | Out-File "$projectName.Infraestructure.Data.csproj" -Encoding UTF8

dotnet restore

@"
namespace $projectName.SharedKernel.Repositories
{
    public interface IRepositorio<T>
    {
        void Agregar(T entidad);
        void Eliminar(int id);
        void Actualizar(T entidad);
        int Contar(Expression<Func<T, bool>> where);
        T ObtenerPorId(int id);
        IEnumerable<T> EncontrarPor(ParametrosDeQuery<T> parametrosDeQuery);
    }
}
"@ | Out-File "$projectDirectory\$projectName.SharedKernel.Repositories\IRepositorio.cs" -Encoding UTF8

@"
using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;

namespace $projectName.SharedKernel.Repositories
{
    public class ParametrosDeQuery<T>
    {
        public ParametrosDeQuery(int pagina, int top)
        {
            Pagina = pagina;
            Top = top;
            Where = null;
            OrderBy = null;
            OrderByDescending = null;
        }

        public int Pagina { get; set; }
        public int Top { get; set; }
        public Expression<Func<T, bool>> Where { get; set; }
        public Func<T, object> OrderBy { get; set; }
        public Func<T, object> OrderByDescending { get; set; }
    }
}
"@ | Out-File "$projectDirectory\$projectName.SharedKernel.Repositories\ParametrosDeQuery.cs" -Encoding UTF8

@"
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

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
"@ | Out-File "$projectDirectory\$projectName.Infraestructure.Data\ApplicationDbContext.cs" -Encoding UTF8

Set-Location $projectDirectory

$projects = @("UIWeb", "Application", "Domain.Entities", "Service", "SharedKernel.Repositories", "Infraestructure.Data")

foreach ($project in $projects) {
    foreach ($otherProject in $projects) {
        if ($project -ne $otherProject) {
            dotnet add "$projectName.$project" reference "$projectName.$otherProject"
        }
    }
}

Write-Host "Proceso completado exitosamente."
Pause