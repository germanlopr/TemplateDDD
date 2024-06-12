*DDD Template projects*

The code snippet automates the creation of a Domain-Driven Design (DDD) project structure using a batch script. It prompts the user for a project name, creates project directories, adds class libraries, creates a UI based on user input, generates project files, and sets up a basic DDD structure with Entity Framework Core.


src/
├── Domain/

│   ├── Entities/

│   ├── ValueObjects/

│   ├── Repositories/

│   ├── Services/

│   └── Exceptions/         // Excepciones específicas del dominio

│

├── Application/

│   ├── Services/

│   ├── Interfaces/

│   ├── Dtos/

│   └── Exceptions/         // Manejo de excepciones a nivel de aplicación

│

├── Infrastructure/

│   ├── Authentication/     // Implementación de JWT

│   ├── Logging/            // Configuración y manejo de Serilog

│   ├── Persistence/

│   └── Services/
│
└── Web/
    ├── Controllers/
    ├── Middleware/
    └── Views/
