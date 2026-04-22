namespace ThoiKhoaBieu.Api.Models;

public sealed class Schedule
{
    public Guid Id { get; set; }

    public DateOnly Date { get; set; }

    public int StartHour { get; set; }

    public int EndHour { get; set; }

    public string TeacherName { get; set; } = string.Empty;

    public string StudentName { get; set; } = string.Empty;

    public string Course { get; set; } = string.Empty;

    public string Content { get; set; } = string.Empty;

    public string? Vehicle { get; set; }

    public string? AssistantName { get; set; }

    public string? Location { get; set; }

    public string? Note { get; set; }

    public string Category { get; set; } = "sa_hinh";

    public Guid CreatedBy { get; set; }

    public string CreatedByEmail { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? UpdatedAt { get; set; }

    public Guid? UpdatedBy { get; set; }
}
