using MusicApp.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Load local secrets (gitignored) â€” overrides appsettings.json placeholders
builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true);

// Add CORS for Angular dev server
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(
                    "http://localhost:4200",
                    "https://localhost:4200",
                    "https://rocket-noble-gotten-walk.trycloudflare.com"
                )
                .AllowAnyMethod()
                .AllowAnyHeader()
                .AllowCredentials();
    });
});

builder.Services.AddControllers();
builder.Services.AddMemoryCache();

// Register services
builder.Services.AddHttpClient();
builder.Services.AddSingleton<SpotifyService>();
builder.Services.AddHttpClient<YouTubeService>();
builder.Services.AddHttpClient<ChatService>();

var app = builder.Build();

app.UseCors();
app.MapControllers();

app.Run();


