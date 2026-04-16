using MusicApp.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Add CORS for Angular dev server
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(
                    "http://localhost:4200",
                    "https://localhost:4200",
                    "https://carry-surgeon-reproduced-announcement.trycloudflare.com"
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

var app = builder.Build();

app.UseCors();
app.MapControllers();

app.Run();

