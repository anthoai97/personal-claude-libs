#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "pytest",
#   "sounddevice",
#   "soundfile",
# ]
# ///
"""Unit tests for notify.py"""

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Import the module under test
sys.path.insert(0, str(Path(__file__).parent.parent / "hooks"))
import notify


class TestPlaySoundFile:
    """Tests for play_sound_file function."""

    def test_missing_file_returns_false(self, tmp_path: Path) -> None:
        """Should return False and print warning for missing file."""
        missing_file = tmp_path / "nonexistent.wav"

        result = notify.play_sound_file(missing_file)

        assert result is False

    def test_missing_file_prints_warning(self, tmp_path: Path, capsys) -> None:
        """Should print warning message for missing file."""
        missing_file = tmp_path / "nonexistent.wav"

        notify.play_sound_file(missing_file)

        captured = capsys.readouterr()
        assert "Warning: Sound file not found" in captured.err
        assert str(missing_file) in captured.err

    @patch("notify.sd")
    @patch("notify.sf")
    def test_plays_sound_with_sounddevice(
        self, mock_sf: MagicMock, mock_sd: MagicMock, tmp_path: Path
    ) -> None:
        """Should play sound using sounddevice and soundfile."""
        sound_file = tmp_path / "test.wav"
        sound_file.touch()

        mock_sf.read.return_value = ([0.1, 0.2], 44100)

        result = notify.play_sound_file(sound_file)

        assert result is True
        mock_sf.read.assert_called_once_with(sound_file)
        mock_sd.play.assert_called_once_with([0.1, 0.2], 44100)
        mock_sd.wait.assert_called_once()

    @patch("notify.sd")
    @patch("notify.sf")
    def test_waits_for_sound_to_finish(
        self, mock_sf: MagicMock, mock_sd: MagicMock, tmp_path: Path
    ) -> None:
        """Should wait for sound to finish playing."""
        sound_file = tmp_path / "test.ogg"
        sound_file.touch()

        mock_sf.read.return_value = ([0.1, 0.2, 0.3], 48000)

        notify.play_sound_file(sound_file)

        mock_sd.wait.assert_called_once()

    @patch("notify.sf")
    def test_handles_read_error(
        self, mock_sf: MagicMock, tmp_path: Path, capsys
    ) -> None:
        """Should return False and print error on read failure."""
        sound_file = tmp_path / "test.wav"
        sound_file.touch()

        mock_sf.read.side_effect = Exception("Failed to read file")

        result = notify.play_sound_file(sound_file)

        assert result is False
        captured = capsys.readouterr()
        assert "Error playing sound" in captured.err

    @patch("notify.sd")
    @patch("notify.sf")
    def test_handles_playback_error(
        self, mock_sf: MagicMock, mock_sd: MagicMock, tmp_path: Path, capsys
    ) -> None:
        """Should return False and print error on playback failure."""
        sound_file = tmp_path / "test.wav"
        sound_file.touch()

        mock_sf.read.return_value = ([0.1], 44100)
        mock_sd.play.side_effect = Exception("Audio device error")

        result = notify.play_sound_file(sound_file)

        assert result is False
        captured = capsys.readouterr()
        assert "Error playing sound" in captured.err


class TestMain:
    """Tests for main function."""

    def test_no_args_shows_usage(self, capsys) -> None:
        """Should show usage when no arguments provided."""
        with patch.object(sys, "argv", ["notify.py"]):
            result = notify.main()

        assert result == 1
        captured = capsys.readouterr()
        assert "Usage:" in captured.err
        assert "{input|complete}" in captured.err

    def test_invalid_arg_shows_usage(self, capsys) -> None:
        """Should show usage for invalid argument."""
        with patch.object(sys, "argv", ["notify.py", "invalid"]):
            result = notify.main()

        assert result == 1
        captured = capsys.readouterr()
        assert "Usage:" in captured.err

    def test_too_many_args_shows_usage(self, capsys) -> None:
        """Should show usage when too many arguments provided."""
        with patch.object(sys, "argv", ["notify.py", "input", "extra"]):
            result = notify.main()

        assert result == 1
        captured = capsys.readouterr()
        assert "Usage:" in captured.err

    @patch("notify.play_sound_file")
    def test_input_arg_plays_input_sound(self, mock_play: MagicMock) -> None:
        """Should play input-needed.wav for 'input' argument."""
        with patch.object(sys, "argv", ["notify.py", "input"]):
            notify.main()

        mock_play.assert_called_once()
        sound_path = mock_play.call_args[0][0]
        assert sound_path.name == "input-needed.wav"

    @patch("notify.play_sound_file")
    def test_complete_arg_plays_complete_sound(self, mock_play: MagicMock) -> None:
        """Should play complete.ogg for 'complete' argument."""
        with patch.object(sys, "argv", ["notify.py", "complete"]):
            notify.main()

        mock_play.assert_called_once()
        sound_path = mock_play.call_args[0][0]
        assert sound_path.name == "complete.ogg"

    @patch("notify.play_sound_file", return_value=True)
    def test_returns_zero_on_success(self, mock_play: MagicMock) -> None:
        """Should return 0 on successful execution."""
        with patch.object(sys, "argv", ["notify.py", "complete"]):
            result = notify.main()

        assert result == 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
