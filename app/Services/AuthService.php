<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthService
{
    /**
     * Authenticate by username + password.
     *
     * @throws ValidationException
     */
    public function loginWithCredentials(string $username, string $password): User
    {
        $user = User::where('username', $username)->first();

        if (! $user || ! Hash::check($password, $user->password)) {
            throw ValidationException::withMessages([
                'username' => ['اسم المستخدم أو كلمة المرور غير صحيحة'],
            ]);
        }

        $this->assertActive($user);

        return $user;
    }

    /**
     * Authenticate by PIN only — used for fast cashier-terminal login,
     * matching the existing Flutter AuthController.loginWithPin().
     *
     * @throws ValidationException
     */
    public function loginWithPin(string $pin): User
    {
        $user = User::where('pin', $pin)->first();

        if (! $user) {
            throw ValidationException::withMessages([
                'pin' => ['رمز PIN غير صحيح'],
            ]);
        }

        $this->assertActive($user);

        return $user;
    }

    /**
     * @throws ValidationException
     */
    protected function assertActive(User $user): void
    {
        if (! $user->is_active) {
            throw ValidationException::withMessages([
                'username' => ['هذا الحساب معطّل، تواصل مع المدير'],
            ]);
        }
    }

    /**
     * Issue a Sanctum token for the given user/device.
     */
    public function issueToken(User $user, ?string $deviceName, bool $remember = true): string
    {
        // One active token per physical device: revoke any previous
        // token issued for the same device name before creating a new
        // one, so a re-login from the same tablet doesn't accumulate
        // orphaned tokens.
        if ($deviceName) {
            $user->tokens()->where('name', $deviceName)->delete();
        }

        $expiresAt = $remember || ! config('sanctum.expiration')
            ? null
            : now()->addMinutes((int) config('sanctum.expiration'));

        $token = $user->createToken(
            $deviceName ?: 'pos-device-'.Str::random(8),
            ['*'],
            $expiresAt
        );

        return $token->plainTextToken;
    }

    public function changePassword(User $user, string $newPassword): void
    {
        $user->forceFill([
            'password' => Hash::make($newPassword),
        ])->save();

        // Revoke every other active session so a stolen token becomes
        // useless the moment the password changes.
        $user->tokens()
            ->where('id', '!=', $user->currentAccessToken()?->id)
            ->delete();
    }

    /**
     * @throws ValidationException
     */
    public function sendPasswordResetLink(string $email): void
    {
        $status = Password::sendResetLink(['email' => $email]);

        if ($status !== Password::RESET_LINK_SENT) {
            throw ValidationException::withMessages([
                'email' => [__($status)],
            ]);
        }
    }

    /**
     * @throws ValidationException
     */
    public function resetPassword(array $credentials): void
    {
        $status = Password::reset(
            $credentials,
            function (User $user, string $password) {
                $user->forceFill([
                    'password' => Hash::make($password),
                ])->save();

                $user->tokens()->delete();
            }
        );

        if ($status !== Password::PASSWORD_RESET) {
            throw ValidationException::withMessages([
                'email' => [__($status)],
            ]);
        }
    }

    public function logout(User $user): void
    {
        $user->currentAccessToken()?->delete();
    }

    public function logoutAllDevices(User $user): void
    {
        $user->tokens()->delete();
    }
}