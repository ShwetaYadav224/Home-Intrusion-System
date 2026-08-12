#!/usr/bin/env python
"""
Update camera stream URLs for devices.
Usage: python update_camera_stream.py
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'homesecurity.settings')
django.setup()

from core.models import Device

def list_devices():
    """List all devices and their stream URLs."""
    print("\n" + "="*60)
    print("CURRENT DEVICES AND STREAM URLs")
    print("="*60)

    devices = Device.objects.all()
    if not devices.exists():
        print("No devices found in database.")
        return

    for i, device in enumerate(devices, 1):
        print(f"\n{i}. Device ID: {device.device_id}")
        print(f"   Name: {device.name or 'Not set'}")
        print(f"   Location: {device.location or 'Not set'}")
        print(f"   Stream URL: {device.stream_url or 'NOT CONFIGURED'}")
        print(f"   Active: {device.is_active}")

def update_stream_url():
    """Update stream URL for a device."""
    print("\n" + "="*60)
    print("UPDATE CAMERA STREAM URL")
    print("="*60)

    devices = Device.objects.all()
    if not devices.exists():
        print("No devices found in database.")
        return

    print("\nSelect a device to update:")
    for i, device in enumerate(devices, 1):
        name = device.name or device.device_id
        current_url = device.stream_url or "NOT SET"
        print(f"{i}. {name} (current: {current_url})")

    try:
        choice = int(input("\nEnter device number: ")) - 1
        if choice < 0 or choice >= len(devices):
            print("Invalid choice!")
            return

        device = devices[choice]
        new_url = input(f"\nEnter new stream URL for {device.name or device.device_id}: ").strip()

        if new_url:
            device.stream_url = new_url
            device.save()
            print(f"\n✅ Updated stream URL for {device.name or device.device_id}")
            print(f"   New URL: {new_url}")
        else:
            print("URL cannot be empty!")

    except ValueError:
        print("Invalid input!")
    except KeyboardInterrupt:
        print("\n\nOperation cancelled.")

def main():
    """Main menu."""
    while True:
        print("\n" + "="*60)
        print("CAMERA STREAM URL MANAGER")
        print("="*60)
        print("1. List all devices")
        print("2. Update stream URL")
        print("3. Exit")

        choice = input("\nEnter choice (1-3): ").strip()

        if choice == "1":
            list_devices()
        elif choice == "2":
            update_stream_url()
        elif choice == "3":
            print("\nGoodbye!")
            break
        else:
            print("Invalid choice!")

if __name__ == "__main__":
    main()
