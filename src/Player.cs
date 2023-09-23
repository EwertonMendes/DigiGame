using Godot;

public partial class Player : CharacterBody2D
{
	private readonly Vector2 PLAYER_POSITION_DEVIATION = new(0, 4);
	private Vector2 initialTileCoords = new(48, 70);

    public override void _Ready()
	{
		GlobalPosition = initialTileCoords - PLAYER_POSITION_DEVIATION;
		GetNode<AnimationPlayer>("AnimationPlayer").Play("walk_up");
	}

	public override void _PhysicsProcess(double delta)
	{
		Move(delta);
		MoveMouse();
		MoveAndSlide();
	}

	private void Move(double delta)
	{
		Velocity = Vector2.Zero;
	}

	private void MoveMouse()
	{
		if (Input.IsActionJustPressed("LeftClick"))
		{
			var selectedTilePosition = (Vector2)GetNode("../Blocks").Get("selectedTile");
			GlobalPosition = selectedTilePosition - PLAYER_POSITION_DEVIATION;
		}
	}
}
