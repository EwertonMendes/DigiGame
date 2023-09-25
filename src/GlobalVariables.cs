using Godot;

public partial class GlobalVariables : Node
{
    public static Vector2I SelectedTileCoords;

    public override void _Process(double delta)
    {
        SelectedTileCoords = (Vector2I)GetTree().Root.GetNode("Main").GetNode("Blocks").Get("selectedTile");
    }
}