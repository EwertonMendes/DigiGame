using System.Collections.Generic;
using Godot;

public partial class DigimonController : Node2D
{

	private List<string> DigimonsToInstantiate = new()
	{
		"agumon",
		"greymon",
	};
	public override void _Ready()
	{

		foreach (var digimon in DigimonsToInstantiate)
		{
			InstantiateDigimon(digimon);
		}

	}

	private void InstantiateDigimon(string digimonName)
	{
		var digimonResource = (Digimon)ResourceLoader.Load($"res://assets/resources/{digimonName}.tres");

		if (digimonResource == null) return;

		var digimonInstance = CreateDigimonInstantce();

		SetDigimonNameAndGraphics(digimonName, digimonResource, digimonInstance);

		SetDigimonInitialPosition(digimonResource, digimonInstance);

		this.AddChild(digimonInstance);
	}

	private CharacterBody2D CreateDigimonInstantce()
	{
		var player = GD.Load<PackedScene>("res://scenes/player.tscn");
		return (CharacterBody2D)player.Instantiate();
	}

	private void SetDigimonNameAndGraphics(string digimonName, Digimon digimonResource, CharacterBody2D digimonInstance)
	{
		var digimonSpriteNode = digimonInstance.GetNode<Sprite2D>("Sprite2D");
		var animationInstance = GD.Load<PackedScene>($"res://scenes/animations/{digimonName}_animations.tscn").Instantiate() as AnimationPlayer;

		digimonInstance.Name = digimonName;
		digimonSpriteNode.Texture = digimonResource.Texture;
		digimonSpriteNode.Frame = digimonResource.InitialFrame;
		digimonSpriteNode.Scale = new Vector2(0.5f, 0.5f);
		
		digimonInstance.AddChild(animationInstance);
	}

	private void SetDigimonInitialPosition(Digimon digimonResource, CharacterBody2D digimonInstance)
	{
		var instanceNode = digimonInstance as Node2D;
		Player digimonScriptInstance = (Player)instanceNode;
		digimonScriptInstance.PLAYER_POSITION_DEVIATION = digimonResource.SpriteDeviation;
		digimonScriptInstance.PARTICLES_POSITION_DEVIATION = digimonResource.ParticleDeviation;
		digimonScriptInstance.initialTileCoords = digimonResource.InitialPosition;
	}

}
