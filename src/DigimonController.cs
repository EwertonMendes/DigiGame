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

		if(digimonResource == null) return;

		var player = GD.Load<PackedScene>("res://scenes/player.tscn");

		var digimonInstance = (CharacterBody2D)player.Instantiate();
		digimonInstance.Name = digimonName;
		digimonInstance.GetNode<Sprite2D>("Sprite2D").Texture = digimonResource.Texture;
		digimonInstance.GetNode<Sprite2D>("Sprite2D").Frame = digimonResource.InitialFrame;
		digimonInstance.GetNode<Sprite2D>("Sprite2D").Scale = new Vector2(0.5f, 0.5f);

		var instanceNode = digimonInstance as Node2D;
		Player digimonScriptInstance = (Player)instanceNode;
		digimonScriptInstance.PLAYER_POSITION_DEVIATION = digimonResource.SpriteDeviation;
		digimonScriptInstance.initialTileCoords = digimonResource.InitialPosition;
		this.AddChild(digimonInstance);
	}
}
