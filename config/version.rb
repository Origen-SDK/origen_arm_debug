module OrigenARMDebug
  MAJOR = 1
  MINOR = 3
  BUGFIX = 1
  DEV = nil
  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
