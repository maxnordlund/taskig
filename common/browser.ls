typeValidator = (type, value) -->
  return void if not value?
  return new Error "Expected type #{type.name} got #{value}" if typeof! value isnt type.name

enumValidator = (validator, allowed, value) -->
  return that if validator value
  return new Error "Expected value in [#{allowed.join ", "}] got #{value}" if value not in allowed

requiredValidator = (validator, value) -->
  return new Error "Expected value to be defined" if not value?
  return validator value

refValidator = (ref, value) -->
  return void if not value?
  return new Error "Expected value to be #ref was #{value.displayName}" if value not instanceof module[ref]

arrayValidator = (validator, array) -->
  result = []
  for value in array when validator value
    result.push that
  return result if result.length isnt 0

objectValidator = (validator, object) -->
  result = {}
  for key, invalid of validator when invalid object[key]
    result[key] = that
  return result if Object.keys result .length isnt 0

class Schema
  (definition) ->
    @_default   = {}
    @_virtual   = {}
    @_validator = @_parse definition, []

  _parse: (definition, path) ->
    switch typeof! definition
      case "Object"
        if definition.default?
          value = @_default
          for sub in initial path
            value = value.{}.[sub]
          value[last path] = definition.default
        #
        if definition.ref?
          return refValidator definition.ref
        else if definition.type?
          validator = typeValidator definition.type
          validator = enumValidator validator, definition.enum if definition.enum?
          validator = requiredValidator validator if definition.required
          return validator
        else
          obj = {}
          for sub, def of definition
            obj[sub] = @_parse def, [...path, sub]
          return objectValidator obj
      case "Array"
        return arrayValidator @_parse definition[0], [...path, 0]
      else
        return typeValidator definition

  validate: (doc) -> @_validator doc

  virtual: (name) ->
    obj = @_virtual
    for path in name.split "." then obj = obj[path] ?= {}
    return
      get: (getter) -> obj.get = getter
      set: (setter) -> obj.set = setter

Model =
  _set: (virtual) ->
    if typeof! virtual.get is "Function"
      return virtual.get.call @
    else
      obj = {}
      for key, val of virtual
        obj[key] = @_set val
      return obj

  _flatten: !(errors, path) ->
    switch typeof! errors
      when "Object"
        for key, err of errors
          @_flatten err, [...path, key]
      when "Array"
        for err, index in errors
          @_flatten err, [...path, index]
      else
        @[path.join "."] = errors

  validate: (cb) ->
    @_flatten @schema.validate(@), <[ errors ]>
    @errors ?= {}
    cb @errors

model = (name, schema) ->
  klass = class Document implements Model
    (input) ->
      @schema = schema
      @displayName = name
      @errors = {}
      import @schema._default
      import input
      import @_set @schema._virtual
  klass.displayName = name
  module[name] = klass
  return klass

export {
  Course: model "Course", require("./schemas/Course.ls") Schema
  Task:   model "Task",   require("./schemas/Task.ls")   Schema
  User:   model "User",   require("./schemas/User.ls")   Schema
}
