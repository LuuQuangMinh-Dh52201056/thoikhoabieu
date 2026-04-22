using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using ThoiKhoaBieu.Api.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterDev", policy =>
    {
        policy
            .WithOrigins("http://localhost:5000", "http://localhost:8080", "http://localhost:3000")
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

builder.Services.AddDbContext<AppDbContext>(options =>
{
    var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
        ?? throw new InvalidOperationException("Missing DefaultConnection.");

    options.UseSqlServer(connectionString);
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();
app.UseCors("FlutterDev");

app.MapGet("/api/health", () => Results.Ok(new
{
    status = "ok",
    service = "ThoiKhoaBieu.Api",
    time = DateTimeOffset.UtcNow,
}));

app.MapGet("/api/health/sql", async (IConfiguration configuration) =>
{
    var connectionString = configuration.GetConnectionString("DefaultConnection");
    if (string.IsNullOrWhiteSpace(connectionString))
    {
        return Results.Problem("Missing DefaultConnection.");
    }

    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();

    await using var command = connection.CreateCommand();
    command.CommandText = "SELECT @@SERVERNAME AS ServerName, DB_NAME() AS DatabaseName";

    await using var reader = await command.ExecuteReaderAsync();
    if (!await reader.ReadAsync())
    {
        return Results.Problem("SQL Server returned no data.");
    }

    return Results.Ok(new
    {
        status = "connected",
        server = reader["ServerName"].ToString(),
        database = reader["DatabaseName"].ToString(),
    });
});

app.MapGet("/api/health/tables", async (AppDbContext db) =>
{
    var userCount = await db.AppUsers.CountAsync();
    var scheduleCount = await db.Schedules.CountAsync();

    return Results.Ok(new
    {
        status = "ok",
        users = userCount,
        schedules = scheduleCount,
    });
});

app.Run();
