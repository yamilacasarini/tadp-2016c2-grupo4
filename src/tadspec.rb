class TADsPec
  def self.obtener_todas_las_clases
    var = (Object.constants).map { |constant| Object.const_get(constant) }
    var = var.select { |constant| constant.is_a? Class }
  end

  def self.search_all_test_suites
    @unit_test_clases = obtener_todas_las_clases
    @unit_test_clases = @unit_test_clases.select { |klass| (klass.instance_methods false).any? { |method| method.to_s.start_with?('testear_que_') } }
  end

  def self.add_test_class(clase)
    @unit_test_clases << clase
  end

  def self.agregar_suites(clase)

    if clase.is_a? Class
      add_test_class(clase)
    else
      search_all_test_suites
    end

  end

  def self.iniciar_entorno
    deberia_proc = proc { |algo| TestContex.deberia_array << (algo.run(self)) }
    mockear_proc = proc { |symbol, &block| self.send :alias_method, ('mock_'+symbol.to_s).to_sym, symbol
    self.send :define_method, symbol, block }
    Object.send :include, TestSuite
    Proc.send :include, TestSuite
    Object.send :define_method, :deberia, deberia_proc
    Proc.send :define_method, :deberia, deberia_proc
    Class.send :define_method, :mockear, mockear_proc
  end

  def self.remove_mock_methods
    mock_method_classes = obtener_todas_las_clases
    mock_method_classes = mock_method_classes.select { |klass| (klass.instance_methods).any? { |method| method.to_s.start_with?('mock_') } }
    mock_method_classes.each { |mocked_class|
      mock_methods = mocked_class.instance_methods.select { |symbol| symbol.to_s.start_with?('mock_') }
      mock_methods.each { |mock_method|
        metodo_a_modificar = mock_method.to_s
        metodo_a_modificar[0..4] = ''
        mocked_class.send :define_method, (metodo_a_modificar.to_sym), (mocked_class.instance_method mock_method)
        mocked_class.send :undef_method, mock_method }
    }
  end

  def self.remover_metodos_peligrosos
    Object.send :remove_method, :deberia
    Proc.send :remove_method, :deberia
    Class.send :remove_method, :mockear
    remove_mock_methods
  end

  def self.remover_modulo_test
    Object.send :uninclude, TestSuite
    Proc.send :uninclude, TestSuite
  end

  def self.testear (clase = nil, *args)
    @unit_test_clases = []
    @test_totales = []
    iniciar_entorno
    agregar_suites clase

    @unit_test_clases.each do |unit_test|
      unit_test.send :include, TestSuite
      @test_totales << TestContex.correr(unit_test, args)
      puts "\n"
    end

    remover_metodos_peligrosos
    generar_reporte(@test_totales.flatten)

  end

  def self.generar_reporte(i)
    print "\n Se corrieron #{i.count} tests de los cuales: "
    print "\n #{i.count true} Pasaron!"
    print "\n #{i.count false} Fallaron!"
    print "\n #{i.count nil} Explotaron! \n"
    i
  end
end

class TADResult

  attr_accessor :resultado, :esperado, :recibido

  def initialize resultado, esperado= nil, recibido= nil
    self.resultado= resultado
    self.esperado= esperado
    self.recibido= recibido
  end

  def analizar_resultados
    if (self.resultado==false)
      puts("esperaba #{esperado} y recibi #{recibido}")
    end
    if (self.resultado==nil)
      puts recibido.backtrace
    end
    self.resultado
  end
end

class Module
  def uninclude(mod)
    mod.instance_methods.each do |method|
      undef_method(method)
    end
  end
end
class TestContex
  def self.correr(clase, lista)
    @var = []
    @object = clase
    if lista.length > 0
      @test_methods = lista
    else
      @test_methods = (@object.instance_methods false).select { |m| m.to_s.start_with?('testear_que_') }
    end
    print "\nLos test de la suite #{@object}:"
    run_test_suite_tests
    @var
  end

  def self.deberia_array
    @deberia
  end

  def self.deberia_init
    @deberia = []
  end

  def self.run_test_suite_tests
    @test_methods.each do |m|
      @var << @object.instance_eval do
        begin
          TestContex.deberia_init
          test = self.new
          analizado = analizar_resultado(test, m.to_sym)
          print "\n El resultado del test: #{m} -> fue: #{analizado.to_s.upcase}"
          analizado
        rescue Exception => a
          print "\n El resultado del test #{m} -> fue: EXPLOSIVO = #{a}"
          (nil)
        end
      end
    end
  end

end

class TADPBlock
  def initialize block
    self.define_singleton_method(:run, block)
  end
end

class TADPObject
  def initialize algo
    @object= algo
  end

  def run algo
    resultado= @object.eql? algo
    TADResult.new resultado, @object, algo
  end
end

class TADPErrorBloc
  def initialize error
    @tipo_error=error
  end

  def run algo
    begin
      algo.call
    rescue Exception => ex
      resultado= ex.class.ancestors.include? (@tipo_error)
      TADResult.new resultado, @tipo_error, ex.class
    end
  end
end

class TADPMethodHistory
  attr_accessor :method, :params

  def initialize method, *params
    self.method= method
    self.params = *params
  end

  def se_llamo symbol, *params
    if params.length==0
      self.method ==symbol
    else
      (self.method == symbol) && (self.params.eql? (params))
    end
  end
end

class TADPSpy
  attr_accessor :spying_object

  def initialize objeto
    self.spying_object = objeto.clone
    @method_list = spying_object.class.instance_methods false
    spying_object.singleton_class.send :attr_accessor, :lista_metodos
    spying_object.send :lista_metodos=, []
    espiar_metodos
  end

  def espiar_metodos
    @method_list.each do |m|
      self.spying_object.class.mockear m  do
        |*args|
      viejo_metodo = ('mock_'+ m.to_s).to_sym
      self.lista_metodos << TADPMethodHistory.new(m, args)
      self.send viejo_metodo, *args
    end

    end
  end

  def method_missing (symbol, *args)
    if spying_object.class.instance_methods.include? symbol
      spying_object.send symbol, *args
    else
      super(symbol, *args)
    end
  end
end

class TADPMethodTester
  attr_accessor :metodo

  def initialize metodo
    self.metodo = metodo
  end

  def run algo
    resultado= algo.spying_object.lista_metodos.any? { |x| x.se_llamo self.metodo }
    TADResult.new resultado, "Uno de #{algo.spying_object.lista_metodos}", metodo
  end

  def veces numero
    self.define_singleton_method :run do |x|
      variable = x.spying_object.lista_metodos.select { |m| m.se_llamo self.metodo
      }
      resultado= variable.length ==numero
      TADResult.new resultado, "que el metodo haya sido llamado #{variable.length} veces", numero
    end
    self
  end

  def con_argumentos *args
    self.define_singleton_method :run do
    |x|
      variable = x.spying_object.lista_metodos.select { |m| m.se_llamo metodo, args }
      resultado= variable.length>0
      TADResult.new resultado, "que el metodo haya recibido #{variable.map { |m| m.params }}", args
    end
    self
  end
end

module TestSuite

  def analizar_resultado(objeto, metodo)
    begin
      objeto.send metodo
      TestContex.deberia_array.all? { |resultado| resultado.analizar_resultados }
    rescue Exception => ex
      puts ex.backtrace
      raise
    end
  end

  def espiar algo

    TADPSpy.new algo

  end


  def mayor_a algo
    proc do
    |x|
      resultado= x > algo
      TADResult.new resultado, "ser mayor a #{x} ", algo
    end
  end

  def menor_a algo
    proc do
    |x|
      resultado= x<algo
      TADResult.new resultado, "ser menor a #{x} ", algo
    end
  end

  def uno_de_estos (primero, *algo)
    proc do |x|
      if primero.is_a? Array
        resultado= primero.include? x
      else
        resultado= (primero.eql? x) || (algo.include? x)
      end
      TADResult.new resultado, "ser uno de a #{primero} ", algo
    end
  end

  def entender symbol
    TADPBlock.new (
                      proc do
                      |x|
                        resultado= x.respond_to? symbol
                        TADResult.new resultado, "alguno de #{x.methods} \n", symbol
                      end)
  end

  def ser (algo)
    if algo.send(:is_a?, Proc)
      TADPBlock.new algo
    else
      TADPObject.new algo
    end
  end


  def haber_recibido algo
    TADPMethodTester.new algo
  end

  def explotar_con algo
    TADPErrorBloc.new algo
  end

  def method_missing(symbol, *args)
    if symbol.to_s.start_with? "ser_"

      TADPBlock.new (proc { |x|
        @string = symbol.to_s
        @string[0..3]= ''
        resultado= x.send(@string.to_sym)
        TADResult.new resultado, true, resultado })

    else
      if symbol.to_s.start_with? "tener_"
        string = symbol.to_s
        string[0..5]=''
        string = ('@' + string)
        if args[0].is_a? Proc
          TADPBlock.new (proc { |x|
            args[0].call(x.instance_variable_get(string.to_sym)) })
        else
          TADPBlock.new (proc { |x|
            resultado= x.instance_variable_get(string.to_sym) == args[0]
            TADResult.new resultado, x.instance_variable_get(string.to_sym), args[0] })
        end
      else
        super(symbol, *args)
      end
    end
  end
end



