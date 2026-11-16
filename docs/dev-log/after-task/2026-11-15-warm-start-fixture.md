# Keep the warm-restart fixture single-start

The warm-restart fixture now explicitly requests one initial start. This keeps its mocked optimizer-call sequence independent of the public multi-start default. All existing warm-restart acceptance and rollback assertions remain in place.

The focused heavy test file passed all 174 expectations in the independent comparison. The full package and release checks remain open; source details are in the check log.
