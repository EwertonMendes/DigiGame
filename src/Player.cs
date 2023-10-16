using Godot;

public partial class Player : CharacterBody2D
{
	public Vector2 PLAYER_POSITION_DEVIATION;
	public Vector2 PARTICLES_POSITION_DEVIATION;
	public Vector2 initialTileCoords;
	private bool isSelected = false;
	private Vector2 selectedTileCoords;
	private AnimationPlayer animationPlayer;

	public override void _Ready()
	{
		GlobalPosition = initialTileCoords + PLAYER_POSITION_DEVIATION;
		animationPlayer = GetNode<AnimationPlayer>("AnimationPlayer");
		animationPlayer.Play("Idle");
	}

	public override void _PhysicsProcess(double delta)
	{
		selectedTileCoords = GlobalVariables.SelectedTileCoords;
	}

	public override void _Input(InputEvent @event)
	{
		@event = @event as InputEventMouseButton;
		if (@event == null) return;

		if (@event is InputEventMouseButton eventMouseButton && eventMouseButton.ButtonIndex == MouseButton.Left)
		{
			if (eventMouseButton.IsReleased() && !IsDigimonPositionClicked() && !isSelected)
			{
				isSelected = false;
				animationPlayer.Play("Idle");
				EmitParticlesWhenSelected();
				return;
			}

			if (eventMouseButton.IsPressed() && isSelected)
			{
				isSelected = false;
				animationPlayer.Play("Idle");
				MoveDigimonPosition();
				EmitParticlesWhenSelected();
				return;
			}

			if (eventMouseButton.IsPressed() && IsDigimonPositionClicked())
			{
				isSelected = true;
				EmitParticlesWhenSelected();
				MoveCameraToSelectedDigimon();
				eventMouseButton.Position = new Vector2(0, 0);
				animationPlayer.Play("walk_up");
				return;
			}
		}
	}

	private bool IsDigimonPositionClicked()
	{
		return selectedTileCoords == (GlobalPosition - PLAYER_POSITION_DEVIATION);
	}

	private void MoveDigimonPosition()
	{
		GlobalPosition = selectedTileCoords + PLAYER_POSITION_DEVIATION;
	}

	private void EmitParticlesWhenSelected()
	{
		var particles = GetNode<Sprite2D>("Sprite2D").GetNode<CpuParticles2D>("CPUParticles2D");
		particles.Position = ToLocal(GlobalPosition) + PARTICLES_POSITION_DEVIATION;
		particles.Emitting = isSelected;
	}

	private void MoveCameraToSelectedDigimon()
	{
		var camera = GetViewport().GetCamera2D();

		if (camera == null) return;

		camera.GlobalPosition = GlobalPosition;
	}
}
