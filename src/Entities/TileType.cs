using Godot;

public class TileType
{
    public string Type { get; }
    public Vector2I Position { get; }

    public TileType(string type, Vector2I position)
    {
        Type = type;
        Position = position;
    }
}