using Godot;
using System;
using System.Collections.Generic;

public partial class Field : TileMap
{
    private const int GridSizeX = 15;
    private const int GridSizeY = 25;
    private readonly Dictionary<Vector2I, Dictionary<string, string>> tileMapData = new();
    public Vector2I selectedTile;

    private readonly List<TileType> tileTypes = new()
    {
        new("DIRT", new Vector2I(0, 0)),
        new("GRASS", new Vector2I(2, 0)),
        new("SNOW", new Vector2I(5, 0))
    };

    public override void _Ready()
    {
        InitializeTileMap();
    }

    private void InitializeTileMap()
    {
        for (int x = 0; x < GridSizeX; x++)
        {
            for (int y = 0; y < GridSizeY; y++)
            {
                var tileType = GetRandomTileType();
                var position = new Vector2I(x, y);
                tileMapData[position] = new Dictionary<string, string>
                {
                    {"type", tileType.Type},
                    {"position", position.ToString()}
                };
                SetCell(0, position, 1, tileType.Position, 0);
            }
        }
    }

    public override void _Process(double delta)
    {
        UpdateTileMapOnHover();
    }

    private void UpdateTileMapOnHover()
    {
        var mousePosition = (Vector2I)GetGlobalMousePosition();
        var tile = LocalToMap(mousePosition + new Vector2I(0, 7));

        ClearHoveredTilesFromField();

        if (tileMapData.TryGetValue(tile, out var hoveredTile))
        {
            selectedTile = (Vector2I)MapToLocal(tile);
            var tileType = FindTileByType(hoveredTile["type"]);
            SetCell(1, tile, 0, tileType.Position, 0);
        }
    }

    private void ClearHoveredTilesFromField()
    {
        foreach (var position in tileMapData.Keys)
        {
            EraseCell(1, position);
        }
    }

    private TileType FindTileByType(string type)
    {
        return tileTypes.Find(tileType => tileType.Type == type);
    }

    private TileType GetRandomTileType()
    {
        var rand = new Random();
        return tileTypes[rand.Next(tileTypes.Count)];
    }
}
