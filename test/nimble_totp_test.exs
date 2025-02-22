defmodule NimbleTOTPTest do
  use ExUnit.Case, async: true
  doctest NimbleTOTP

  describe "otpauth_uri" do
    test "Generate the QR Code uri without params" do
      secret = Base.decode32!("PTEPUGZ7DUWTBGMW4WLKB6U63MGKKMCA")

      assert NimbleTOTP.otpauth_uri("bytepack", secret) ==
               "otpauth://totp/bytepack?secret=PTEPUGZ7DUWTBGMW4WLKB6U63MGKKMCA"
    end

    test "Generate the uri with extra params" do
      secret = Base.decode32!("PTEPUGZ7DUWTBGMW4WLKB6U63MGKKMCA")
      app = "Bytepack App"

      assert NimbleTOTP.otpauth_uri("#{app}:user@test.com", secret, issuer: app) == """
             otpauth://totp/Bytepack%20App:user@test.com?\
             secret=PTEPUGZ7DUWTBGMW4WLKB6U63MGKKMCA&\
             issuer=Bytepack%20App\
             """
    end
  end

  describe "secret" do
    test "generate a binary with 10 bytes" do
      secret = NimbleTOTP.secret(10)

      assert byte_size(secret) == 10
    end

    test "generate a binary with 20 bytes by default" do
      secret = NimbleTOTP.secret()

      assert byte_size(secret) == 20
    end

    test "always generate a different randon secret" do
      secrets = Enum.map(1..1000, fn _ -> NimbleTOTP.secret() end)
      assert Enum.uniq(secrets) == secrets
    end
  end

  describe "verification code" do
    test "generate 6 digit verification codes" do
      now = System.os_time(:second)

      for _ <- 1..1000 do
        secret = NimbleTOTP.secret()
        assert NimbleTOTP.verification_code(secret, time: now) =~ ~r/\d{6}/
      end
    end

    test "generate 4 digit verification codes" do
      now = System.os_time(:second)

      for _ <- 1..1000 do
        secret = NimbleTOTP.secret()
        assert NimbleTOTP.verification_code(secret, time: now, totp_size: 4) =~ ~r/\d{4}/
      end
    end

    test "add leading zeros to reach length 6" do
      secret = Base.decode32!("BKFCZBQPZOXNTER5HKHGPHPGCXBNBDNC")
      time = to_unix(~N[2020-04-08 18:09:11Z])

      assert NimbleTOTP.verification_code(secret, time: time) == "005357"
    end

    test "add leading zeros to reach length 4" do
      secret = Base.decode32!("BKFCZBQPZOXNTER5HKHGPHPGCXBNBDNA")
      time = to_unix(~N[2023-01-17 06:36:22Z])

      assert NimbleTOTP.verification_code(secret, time: time, totp_size: 4) == "0760"
    end

    test "generate different codes in different periods (default is 30s)" do
      secret = NimbleTOTP.secret()
      time1 = ~N[2020-04-08 17:49:59Z]
      time2 = ~N[2020-04-08 17:50:00Z]
      time3 = ~N[2020-04-08 17:50:30Z]

      code1 = NimbleTOTP.verification_code(secret, time: time1)
      assert code1 == NimbleTOTP.verification_code(secret, time: to_unix(time1))
      code2 = NimbleTOTP.verification_code(secret, time: time2)
      assert code2 == NimbleTOTP.verification_code(secret, time: to_unix(time2))
      code3 = NimbleTOTP.verification_code(secret, time: time3)
      assert code3 == NimbleTOTP.verification_code(secret, time: to_unix(time3))

      codes = [code1, code2, code3]

      assert Enum.uniq(codes) == codes
    end

    test "generate different codes in different periods (default is 30s, 4 digit)" do
      secret = NimbleTOTP.secret()
      time1 = ~N[2020-04-08 17:49:59Z]
      time2 = ~N[2020-04-08 17:50:00Z]
      time3 = ~N[2020-04-08 17:50:30Z]

      code1 = NimbleTOTP.verification_code(secret, time: time1, totp_size: 4)
      assert code1 == NimbleTOTP.verification_code(secret, time: to_unix(time1), totp_size: 4)
      code2 = NimbleTOTP.verification_code(secret, time: time2, totp_size: 4)
      assert code2 == NimbleTOTP.verification_code(secret, time: to_unix(time2), totp_size: 4)
      code3 = NimbleTOTP.verification_code(secret, time: time3, totp_size: 4)
      assert code3 == NimbleTOTP.verification_code(secret, time: to_unix(time3), totp_size: 4)

      codes = [code1, code2, code3]

      assert Enum.uniq(codes) == codes
    end

    test "generate the same code in the same period" do
      secret = NimbleTOTP.secret()
      time1 = to_unix(~N[2020-04-08 17:50:00Z])
      time2 = to_unix(~N[2020-04-08 17:50:29Z])
      code1 = NimbleTOTP.verification_code(secret, time: time1)
      code2 = NimbleTOTP.verification_code(secret, time: time2)

      assert code1 == code2
    end
  end

  describe "valid?/2" do
    test "returns true if it matches the verification code" do
      time = System.os_time(:second)
      date_time = DateTime.from_unix!(time, :second)
      naive_date_time = DateTime.to_naive(date_time)

      for _ <- 1..1000 do
        secret = NimbleTOTP.secret()

        code = NimbleTOTP.verification_code(secret, time: time)
        assert code == NimbleTOTP.verification_code(secret, time: date_time)
        assert code == NimbleTOTP.verification_code(secret, time: naive_date_time)

        assert NimbleTOTP.valid?(secret, code, time: time)
        assert NimbleTOTP.valid?(secret, code, time: date_time)
        assert NimbleTOTP.valid?(secret, code, time: naive_date_time)

        refute NimbleTOTP.valid?(secret, "abcdef", time: time)
        refute NimbleTOTP.valid?(secret, "abcdef", time: date_time)
        refute NimbleTOTP.valid?(secret, "abcdef", time: naive_date_time)
      end
    end

    test "returns true if it matches the verification code (4 digit)" do
      time = System.os_time(:second)
      date_time = DateTime.from_unix!(time, :second)
      naive_date_time = DateTime.to_naive(date_time)

      for _ <- 1..1000 do
        secret = NimbleTOTP.secret()

        code = NimbleTOTP.verification_code(secret, time: time, totp_size: 4)
        assert code == NimbleTOTP.verification_code(secret, time: date_time, totp_size: 4)
        assert code == NimbleTOTP.verification_code(secret, time: naive_date_time, totp_size: 4)

        assert NimbleTOTP.valid?(secret, code, time: time, totp_size: 4)
        assert NimbleTOTP.valid?(secret, code, time: date_time, totp_size: 4)
        assert NimbleTOTP.valid?(secret, code, time: naive_date_time, totp_size: 4)

        refute NimbleTOTP.valid?(secret, "abcd", time: time, totp_size: 4)
        refute NimbleTOTP.valid?(secret, "abcd", time: date_time, totp_size: 4)
        refute NimbleTOTP.valid?(secret, "abcd", time: naive_date_time, totp_size: 4)
      end
    end

    test "returns true if it matches the verification code (10 digit)" do
      time = System.os_time(:second)
      date_time = DateTime.from_unix!(time, :second)
      naive_date_time = DateTime.to_naive(date_time)

      for _ <- 1..1000 do
        secret = NimbleTOTP.secret()

        code = NimbleTOTP.verification_code(secret, time: time, totp_size: 10)
        assert code == NimbleTOTP.verification_code(secret, time: date_time, totp_size: 10)
        assert code == NimbleTOTP.verification_code(secret, time: naive_date_time, totp_size: 10)

        assert NimbleTOTP.valid?(secret, code, time: time, totp_size: 10)
        assert NimbleTOTP.valid?(secret, code, time: date_time, totp_size: 10)
        assert NimbleTOTP.valid?(secret, code, time: naive_date_time, totp_size: 10)
      end
    end

    test "rejects reused verification codes" do
      time = System.os_time(:second)
      next_time = (Integer.floor_div(time, 30) + 1) * 30

      for _ <- 1..1000 do
        secret = NimbleTOTP.secret()
        code = NimbleTOTP.verification_code(secret, time: time)
        next_code = NimbleTOTP.verification_code(secret, time: next_time)
        assert NimbleTOTP.valid?(secret, code, time: time)
        refute NimbleTOTP.valid?(secret, "abcdef", time: time)

        # Rejects all invalid codes regardless of the since option
        refute NimbleTOTP.valid?(secret, "abcdef", time: time, since: time)
        refute NimbleTOTP.valid?(secret, "abcdef", time: time, since: next_time)
        refute NimbleTOTP.valid?(secret, "abcdef", time: time, since: nil)

        # If since is nil (e.g. first time the code is entered)
        assert NimbleTOTP.valid?(secret, code, time: time, since: nil)

        # If the code was just entered
        refute NimbleTOTP.valid?(secret, code, time: time, since: time)

        # If the next code is entered in the last time-step window
        assert NimbleTOTP.valid?(secret, next_code, time: next_time, since: time)
      end
    end

    test "returns false if the code does not have 6 digits" do
      time = System.os_time(:second)
      secret = NimbleTOTP.secret()
      code = NimbleTOTP.verification_code(secret, time: time)
      refute NimbleTOTP.valid?(secret, "", time: time)
      refute NimbleTOTP.valid?(secret, binary_part(code, 0, 5), time: time)
      refute NimbleTOTP.valid?(secret, <<?0, code::binary>>, time: time)
    end
  end

  defp to_unix(naive_datetime),
    do: naive_datetime |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
end
