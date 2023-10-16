using Godot;

[GlobalClass]
public partial class Digimon : Resource
{
    [Export] public Texture2D Texture { get; set; }
    [Export] public int InitialFrame { get; set; }
    [Export] public Vector2 SpriteDeviation { get; set; }
    [Export] public Vector2 ParticleDeviation { get; set; }
    [Export] public Vector2I InitialPosition { get; set; }
    [Export] public string Type { get; set; }
    [Export] public string Name { get; set; }
    [Export] public int Level { get; set; }
    [Export] public int Hp { get; set; }
    [Export] public int Mp { get; set; }
    [Export] public int Attack { get; set; }
    [Export] public int Defense { get; set; }
    [Export] public int Age { get; set; }
    [Export] public int Battles { get; set; }
    [Export] public int Victories { get; set; }
    [Export] public int Defeats { get; set; }

}