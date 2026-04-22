using Microsoft.EntityFrameworkCore;
using ThoiKhoaBieu.Api.Models;

namespace ThoiKhoaBieu.Api.Data;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<AppUser> AppUsers => Set<AppUser>();

    public DbSet<Schedule> Schedules => Set<Schedule>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<AppUser>(entity =>
        {
            entity.ToTable("AppUsers");
            entity.HasKey(user => user.Id);
            entity.HasIndex(user => user.Email).IsUnique();
            entity.Property(user => user.Email).HasMaxLength(256);
            entity.Property(user => user.PasswordHash).HasMaxLength(500);
            entity.Property(user => user.DisplayName).HasMaxLength(160);
            entity.Property(user => user.Role).HasMaxLength(20);
        });

        modelBuilder.Entity<Schedule>(entity =>
        {
            entity.ToTable("Schedules");
            entity.HasKey(schedule => schedule.Id);
            entity.Property(schedule => schedule.TeacherName).HasMaxLength(160);
            entity.Property(schedule => schedule.StudentName).HasMaxLength(160);
            entity.Property(schedule => schedule.Course).HasMaxLength(30);
            entity.Property(schedule => schedule.Content).HasMaxLength(500);
            entity.Property(schedule => schedule.Vehicle).HasMaxLength(80);
            entity.Property(schedule => schedule.AssistantName).HasMaxLength(160);
            entity.Property(schedule => schedule.Location).HasMaxLength(240);
            entity.Property(schedule => schedule.Note).HasMaxLength(1000);
            entity.Property(schedule => schedule.Category).HasMaxLength(80);
            entity.Property(schedule => schedule.CreatedByEmail).HasMaxLength(256);

            entity
                .HasOne<AppUser>()
                .WithMany()
                .HasForeignKey(schedule => schedule.CreatedBy)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
