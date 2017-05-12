module OrigenARMDebug
  MAJOR = 1
  MINOR = 0
  BUGFIX = 0
  DEV = 1

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
