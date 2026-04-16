using Microsoft.AspNetCore.Mvc;
using MusicApp.Api.Services;

namespace MusicApp.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly SpotifyService _spotifyService;

    public AuthController(SpotifyService spotifyService)
    {
        _spotifyService = spotifyService;
    }

    [HttpGet("spotify/login")]
    public IActionResult SpotifyLogin()
    {
        var url = _spotifyService.GetAuthorizationUrl();
        return Ok(new { url });
    }

    [HttpGet("spotify/callback")]
    public async Task<IActionResult> SpotifyCallback([FromQuery] string code)
    {
        if (string.IsNullOrEmpty(code))
            return BadRequest("Authorization code is required");

        var token = await _spotifyService.ExchangeCodeAsync(code);
        if (token == null)
            return BadRequest("Failed to exchange code for token");

        // In production: store tokens server-side in a session or database
        // For now, return to the frontend with token info
        return Ok(token);
    }

    [HttpPost("spotify/refresh")]
    public async Task<IActionResult> RefreshSpotifyToken([FromBody] RefreshRequest request)
    {
        if (string.IsNullOrEmpty(request.RefreshToken))
            return BadRequest("Refresh token is required");

        var token = await _spotifyService.RefreshTokenAsync(request.RefreshToken);
        if (token == null)
            return BadRequest("Failed to refresh token");

        return Ok(token);
    }
}

public class RefreshRequest
{
    public string RefreshToken { get; set; } = string.Empty;
}
