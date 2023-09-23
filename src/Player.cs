using Godot;

public partial class Player : CharacterBody2D
{
	private readonly Vector2 PLAYER_POSITION_DEVIATION = new(0, 4);
	private Vector2 initialTileCoords = new(48, 70);

	private bool isSelected = false;

	private Vector2 selectedTileCoords;


	public override void _Ready()
	{
		GlobalPosition = initialTileCoords - PLAYER_POSITION_DEVIATION;
		GetNode<AnimationPlayer>("AnimationPlayer").Play("walk_up");
	}

	public override void _PhysicsProcess(double delta)
	{
		selectedTileCoords = (Vector2)GetNode("../Blocks").Get("selectedTile");
	}

	public override void _Input(InputEvent @event)
	{
		@event = @event as InputEventMouseButton;
		if (@event == null) return;

		if (@event is InputEventMouseButton eventMouseButton && eventMouseButton.ButtonIndex == MouseButton.Left)
		{
			if (eventMouseButton.IsReleased() && !IsDigimonPositionClicked())
			{
				isSelected = false;
				return;
			}

			if (eventMouseButton.IsPressed() && isSelected)
			{
				MoveDigimonPosition();
				isSelected = false;
				return;
			}

			if (eventMouseButton.IsPressed() && IsDigimonPositionClicked())
			{
				isSelected = true;
				return;
			}
		}
	}

	private bool IsDigimonPositionClicked()
	{
		var selectedTilePosition = (Vector2)GetNode("../Blocks").Get("selectedTile");
		return selectedTilePosition == (GlobalPosition + PLAYER_POSITION_DEVIATION);
	}

	private void MoveDigimonPosition()
	{
		GlobalPosition = selectedTileCoords - PLAYER_POSITION_DEVIATION;
	}

}
