import runpy, sys
from pathlib import Path
runner = Path(__file__).with_name("run_batch.py")
sys.argv = [str(runner), sys.argv[1], "engineering"]
runpy.run_path(str(runner), run_name="__main__")
