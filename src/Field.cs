using Godot;
using System;
using System.Collections.Generic;

public partial class Field : TileMap
{
    private int GridSizeX = 30;
    private int GridSizeY = 50;
    private Dictionary<string, Dictionary<string, string>> Dic = new();
    private Vector2 selectedTile;

    private List<Dictionary<string, object>> tileTypes = new List<Dictionary<string, object>>
    {
        new Dictionary<string, object>
        {
            {"type", "DIRT"},
            {"position", new Vector2I(0, 0)}
        },
        new Dictionary<string, object>
        {
            {"type", "GRASS"},
            {"position", new Vector2I(2, 0)}
        },
        new Dictionary<string, object>
        {
            {"type", "SNOW"},
            {"position", new Vector2I(5, 0)}
        }
    };

    public override void _Ready()
    {
        for (int x = 0; x < GridSizeX; x++)
        {
            for (int y = 0; y < GridSizeY; y++)
            {
                var tileType = tileTypes[(int)GD.Randi() % tileTypes.Count];
                Dic[new Vector2(x, y).ToString()] = new Dictionary<string, string>
                {
                    {"type", (string)tileType["type"]},
                    {"position", new Vector2(x, y).ToString()}
                };
                SetCell(0, new Vector2I(x, y), 1, (Vector2I)tileType["position"], 0);
            }
        }
    }

    public override void _Process(double delta)
    {
        var mousePosition = (Vector2I)GetGlobalMousePosition();
        var tile = (Vector2I) MapToLocal(mousePosition + new Vector2I(0, 7));

        for (int x = 0; x < GridSizeX; x++)
        {
            for (int y = 0; y < GridSizeY; y++)
            {
                EraseCell(1, new Vector2I(x, y));
            }
        }

        if (Dic.ContainsKey(tile.ToString()))
        {
            selectedTile = tile;
            var hoveredTile = Dic[tile.ToString()];
            var tileType = FindTileByType((string)hoveredTile["type"]);
            SetCell(1, tile, 0, (Vector2I)tileType["position"], 0);
        }
    }

    private Dictionary<string, object> FindTileByType(string type)
    {
        foreach (var tileType in tileTypes)
        {
            if ((string)tileType["type"] == type)
            {
                return tileType;
            }
        }
        return null;
    }
}
