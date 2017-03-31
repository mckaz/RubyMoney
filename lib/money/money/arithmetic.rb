require 'rdl'
require 'types/core'

class Money
  module Arithmetic
    # Wrapper for coerced numeric values to distinguish
    # when numeric was on the 1st place in operation.
    CoercedNumeric = Struct.new(:value) do
      # Proxy #zero? method to skip unnecessary typecasts. See #- and #+.
      # NV TODO this is not accepted 
      # type Money::Arithmetic::CoercedNumeric, :zero?, '() -> %bool'
      def zero?
        value.zero?
      end
    end

    # Library annotations 
    type Kernel, :respond_to?, '(%any) -> %bool'

    type Money, :fractional,  '() -> %real'
    type Money, :currency,    '() -> %real'
    type Money, :cents,       '() -> %real'
    type Money, :zero?,       '() -> %bool'
    type Money, :exchange_to, '(%real) -> Money'
    type Money, :<,           '(Money or %real) -> %bool'
    type Money, :-,           '(Money or %real) -> Money or %real'
    type Money, :>,           '(Money or %real) -> %bool'

    type Money::Arithmetic, :fractional, '() -> %real'
    type Money::Arithmetic, :currency,   '() -> %real'
    type Money::Arithmetic, :as_d,       '(%real or Money) -> %real'

    type Class, :new, '(%real, %real) -> %bot'

    type Bignum, :value, '() -> %integer'
    type Fixnum, :value, '() -> %integer'

    type Rational,   :exchange_to, '(Object) -> Money'
    type Float,      :exchange_to, '(%real) -> Money'
    type BigDecimal, :exchange_to, '(%real) -> Money'
    type Bignum,     :exchange_to, '(%real) -> Money'
    type Fixnum,     :exchange_to, '(%real) -> Money'

    # Returns a money object with changed polarity.
    #
    # @return [Money]
    #
    # @example
    #    - Money.new(100) #=> #<Money @fractional=-100>
    type '() -> Money out {{ self.fractional = -out.fractional }}', typecheck: :now
    def -@
      self.class.new(-fractional, currency)
    end

    # Checks whether two Money objects have the same currency and the same
    # amount. If Money objects have a different currency it will only be true
    # if the amounts are both zero. Checks against objects that are not Money or
    # a subclass will always return false.
    #
    # @param [Money] other_money Value to compare with.
    #
    # @return [Boolean]
    #
    # @example
    #   Money.new(100).eql?(Money.new(101))                #=> false
    #   Money.new(100).eql?(Money.new(100))                #=> true
    #   Money.new(100, "USD").eql?(Money.new(100, "GBP"))  #=> false
    #   Money.new(0, "USD").eql?(Money.new(0, "EUR"))      #=> true
    #   Money.new(100).eql?("1.00")                        #=> false
    type '(Money m) -> %bool b {{ if (m.fractional == 0) && (self.fractional == 0) then b == true end }}', typecheck: :now
    def eql?(other_money)
      if other_money.is_a?(Money)
        (fractional == other_money.fractional && currency == other_money.currency) ||
          (fractional == 0 && other_money.fractional == 0)
      else
        false
      end
    end

    # Compares two Money objects. If money objects have a different currency it
    # will attempt to convert the currency.
    #
    # @param [Money] other_money Value to compare with.
    #
    # @return [Integer]
    #
    # @raise [TypeError] when other object is not Money
    #

    ## NV: The below type is conservative but generalization requires occurence typing
    ## NV: Parser bug? initial `rescue Money::Bank::UnknownRate` would not type check

    type '(Money) -> Object', typecheck: :now
    def <=>(other)
      unless other.is_a?(Money)
        return unless other.respond_to?(:zero?) && other.zero?
        return other.is_a?(CoercedNumeric) ? 0 <=> fractional : fractional <=> 0
      end
      other = other.exchange_to(currency)
      fractional <=> other.fractional
    rescue 
      Money::Bank::UnknownRate
# NV rewrite       
#   rescue Money::Bank::UnknownRate
    end

    # Uses Comparable's implementation but raises ArgumentError if non-zero
    # numeric value is given.
    type '(Money or %integer other) -> %bool b {{ self == other || other == 0}}', typecheck: :now
    def ==(other)
      if other.is_a?(Numeric) && !other.zero?
        raise ArgumentError, 'Money#== supports only zero numerics'
      end
      self == other
# NV rewrite       
#      super
    end

    # Test if the amount is positive. Returns +true+ if the money amount is
    # greater than 0, +false+ otherwise.
    #
    # @return [Boolean]
    #
    # @example
    #   Money.new(1).positive?  #=> true
    #   Money.new(0).positive?  #=> false
    #   Money.new(-1).positive? #=> false
    type '() -> %bool b {{ b == self.fractional > 0 }}', typecheck: :now
    def positive?
      fractional > 0
    end

    # Test if the amount is negative. Returns +true+ if the money amount is
    # less than 0, +false+ otherwise.
    #
    # @return [Boolean]
    #
    # @example
    #   Money.new(-1).negative? #=> true
    #   Money.new(0).negative?  #=> false
    #   Money.new(1).negative?  #=> false

    type :negative?, '() -> %bool b {{ b = self.fractional < 0 }}', typecheck: :now
    def negative?
      fractional < 0
    end

    # @method +(other)
    # Returns a new Money object containing the sum of the two operands' monetary
    # values. If +other_money+ has a different currency then its monetary value
    # is automatically exchanged to this object's currency using +exchange_to+.
    #
    # @param [Money] other_money Other +Money+ object to add.
    #
    # @return [Money]
    #
    # @example
    #   Money.new(100) + Money.new(100) #=> #<Money @fractional=200>
    #
    # @method -(other)
    # Returns a new Money object containing the difference between the two
    # operands' monetary values. If +other_money+ has a different currency then
    # its monetary value is automatically exchanged to this object's currency
    # using +exchange_to+.
    #
    # @param [Money] other_money Other +Money+ object to subtract.
    #
    # @return [Money]
    #
    # @example
    #   Money.new(100) - Money.new(99) #=> #<Money @fractional=1>
    
    [:+, :-].each do |op|
      define_method(op) do |other|
        unless other.is_a?(Money)
          return self if other.zero?
          raise TypeError
        end
        other = other.exchange_to(currency)
        self.class.new(fractional.public_send(op, other.fractional), currency)
        type op, '(Money) -> Money', typecheck: :now 
      end
    end

    # Multiplies the monetary value with the given number and returns a new
    # +Money+ object with this monetary value and the same currency.
    #
    # Note that you can't multiply a Money object by an other +Money+ object.
    #
    # @param [Numeric] value Number to multiply by.
    #
    # @return [Money] The resulting money.
    #
    # @raise [TypeError] If +value+ is NOT a number.
    #
    # @example
    #   Money.new(100) * 2 #=> #<Money @fractional=200>
    #

    type '(%integer) -> Money m {{ m.fractional == self.fractional * value }}', typecheck: :now
    def *(value)
      value = value.value if value.is_a?(CoercedNumeric)
      if value.is_a? Numeric
        self.class.new(fractional * value, currency)
      else
        raise TypeError, "Can't multiply a #{self.class.name} by a #{value.class.name}'s value"
      end
    end

    # Divides the monetary value with the given number and returns a new +Money+
    # object with this monetary value and the same currency.
    # Can also divide by another +Money+ object to get a ratio.
    #
    # +Money/Numeric+ returns +Money+. +Money/Money+ returns +Float+.
    #
    # @param [Money, Numeric] value Number to divide by.
    #
    # @return [Money] The resulting money if you divide Money by a number.
    # @return [Float] The resulting number if you divide Money by a Money.
    #
    # @example
    #   Money.new(100) / 10            #=> #<Money @fractional=10>
    #   Money.new(100) / Money.new(10) #=> 10.0
    #
   type '(%real) -> Money or %real m {{ m.fractional == self.fractional * value }}', typecheck: :now
   def /(value)
      if value.is_a?(self.class)
        fractional / as_d(value.exchange_to(currency).fractional).to_f
      else
        raise TypeError, 'Can not divide by Money' if value.is_a?(CoercedNumeric)
        self.class.new(fractional / as_d(value), currency)
      end
    end

    # Synonym for +#/+.
    #
    # @param [Money, Numeric] value Number to divide by.
    #
    # @return [Money] The resulting money if you divide Money by a number.
    # @return [Float] The resulting number if you divide Money by a Money.
    #
    # @see #/
    #
    type '(%real) -> Money or %real m {{ m.fractional == self.fractional * value }}', typecheck: :now
    def div(value)
      self / value
    end

    # Divide money by money or fixnum and return array containing quotient and
    # modulus.
    #
    # @param [Money, Integer] val Number to divmod by.
    #
    # @return [Array<Money,Money>,Array<Integer,Money>]
    #
    # @example
    #   Money.new(100).divmod(9)            #=> [#<Money @fractional=11>, #<Money @fractional=1>]
    #   Money.new(100).divmod(Money.new(9)) #=> [11, #<Money @fractional=1>]
    # type here

   type Money::Arithmetic, :divmod_money, '(%real or Money) -> [%real, Money]', typecheck: :now 
   type Money::Arithmetic, :divmod_other, '(%real or Money) -> [%real, Money]', typecheck: :now 
   type '(%real) -> [%real, Money]', typecheck: :now 
   def divmod(val)
      if val.is_a?(Money)
        divmod_money(val)
      else
        divmod_other(val)
      end
    end

    def divmod_money(val)
      cents = val.exchange_to(currency).cents
      quotient, remainder = fractional.divmod(cents)
      [quotient, self.class.new(remainder, currency)]
    end
    private :divmod_money

    def divmod_other(val)
      quotient, remainder = fractional.divmod(as_d(val))
      [self.class.new(quotient, currency), self.class.new(remainder, currency)]
    end
    private :divmod_other

    # Equivalent to +self.divmod(val)[1]+
    #
    # @param [Money, Integer] val Number take modulo with.
    #
    # @return [Money]
    #
    # @example
    #   Money.new(100).modulo(9)            #=> #<Money @fractional=1>
    #   Money.new(100).modulo(Money.new(9)) #=> #<Money @fractional=1>

    # NV this is too general: the result is always Money
    type '(%real or Money) -> Money' 
    def modulo(val)
      divmod(val)[1]
    end

    # Synonym for +#modulo+.
    #
    # @param [Money, Integer] val Number take modulo with.
    #
    # @return [Money]
    #
    # @see #modulo
    type '(%real or Money) -> %real or Money', typecheck: :now 
    def %(val)
      modulo(val)
    end

    # If different signs +self.modulo(val) - val+ otherwise +self.modulo(val)+
    #
    # @param [Money, Integer] val Number to rake remainder with.
    #
    # @return [Money]
    #
    # @example
    #   Money.new(100).remainder(9) #=> #<Money @fractional=1>

    # NV TODO: requires occurence typing 
    type '(%real or Money) -> %real or Money' 
    def remainder(val)
      if val.is_a?(Money) && currency != val.currency
        val = val.exchange_to(currency)
      end

      if (fractional < 0 && val < 0) || (fractional > 0 && val > 0)
        self.modulo(val)
      else
        self.modulo(val) - (val.is_a?(Money) ? val : self.class.new(val, currency))
      end
    end

  type '(Money) -> %real or Money', typecheck: :now 
    def remainder_money(val)
      if val.is_a?(Money) && currency != val.currency
        val = val.exchange_to(currency)
      end

      if (fractional < 0 && val < 0) || (fractional > 0 && val > 0)
        self.modulo(val)
      else
        self.modulo(val) - val
      end
    end


    type '(%real) -> %real or Money', typecheck: :now 
    def remainder_real(val)
      if (fractional < 0 && val < 0) || (fractional > 0 && val > 0)
        self.modulo(val)
      else
        self.modulo(val) - self.class.new(val, currency)
      end
    end


    # Return absolute value of self as a new Money object.
    #
    # @return [Money]
    #
    # @example
    #   Money.new(-100).abs #=> #<Money @fractional=100>
    type '() -> Money m {{ if self.fractional >= 0 then m.fractional == self.fractional else m.fractional == -self.fractional end }}', typecheck: :now
    def abs
      self.class.new(fractional.abs, currency)
    end

    # Test if the money amount is zero.
    #
    # @return [Boolean]
    #
    # @example
    #   Money.new(100).zero? #=> false
    #   Money.new(0).zero?   #=> true
    type '() -> %bool b {{ b == (self.fractional == 0) }}', typecheck: :now
    def zero?
      fractional == 0
    end

    # Test if the money amount is non-zero. Returns this money object if it is
    # non-zero, or nil otherwise, like +Numeric#nonzero?+.
    #
    # @return [Money, nil]
    #
    # @example
    #   Money.new(100).nonzero? #=> #<Money @fractional=100>
    #   Money.new(0).nonzero?   #=> nil
    type '() -> %bool'
    def nonzero?
      fractional != 0 ? self : nil
    end

    # Used to make Money instance handle the operations when arguments order is reversed
    # @return [Array]
    #
    # @example
    #   2 * Money.new(10) #=> #<Money @fractional=20>

    # NV TODO
    type '(%integer) -> [Money]'
    def coerce(other)
      [self, CoercedNumeric.new(other)]
    end
  end
end
