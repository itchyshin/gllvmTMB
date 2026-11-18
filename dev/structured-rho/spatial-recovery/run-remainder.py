"""Launch only the approved post-checkpoint 1,568 retained attempts."""
import runpy, sys
from pathlib import Path

runner = Path(__file__).with_name("run_batch.py")
sys.argv = [str(runner), sys.argv[1], "remainder"]
runpy.run_path(str(runner), run_name="__main__")
