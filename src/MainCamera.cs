using Godot;

public partial class MainCamera : Camera2D
{
    private Vector2 MIN_ZOOM = new(1, 1);
    private Vector2 MAX_ZOOM = new(4, 4);
    private Vector2 ZOOM_FACTOR = new(0.25f, 0.25f);

    private void HandleZoom()
    {
        Vector2 currentZoom = Zoom;
        if (Input.IsActionJustReleased("wheel_down") && currentZoom >= MIN_ZOOM)
        {
            Zoom = currentZoom - ZOOM_FACTOR;
        }
        if (Input.IsActionJustReleased("wheel_up") && currentZoom <= MAX_ZOOM)
        {
            Zoom = currentZoom + ZOOM_FACTOR;
        }
    }

    public override void _PhysicsProcess(double delta)
    {
        HandleZoom();
    }
}
