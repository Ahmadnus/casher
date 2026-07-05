<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ChangePasswordRequest;
use App\Http\Requests\Auth\ForgotPasswordRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\ResetPasswordRequest;
use App\Http\Resources\UserResource;
use App\Services\AuthService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function __construct(protected AuthService $authService) {}

    /**
     * POST /api/auth/login
     *
     * Body (credentials mode):
     *   { "mode": "credentials", "username": "admin", "password": "admin123",
     *     "device_name": "Cashier Tablet 1", "remember": true }
     *
     * Body (PIN mode):
     *   { "mode": "pin", "pin": "0000", "device_name": "Cashier Tablet 1" }
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $data = $request->validated();

        $user = $data['mode'] === 'pin'
            ? $this->authService->loginWithPin($data['pin'])
            : $this->authService->loginWithCredentials($data['username'], $data['password']);

        $token = $this->authService->issueToken(
            $user,
            $data['device_name'] ?? null,
            $data['remember'] ?? true
        );

        $user->recordLogin($request->ip());

        return response()->json([
            'success' => true,
            'message' => 'تم تسجيل الدخول بنجاح',
            'data' => [
                'token' => $token,
                'token_type' => 'Bearer',
                'user' => new UserResource($user->load('roles')),
            ],
        ]);
    }

    /**
     * POST /api/auth/logout
     * Revokes only the token used for this request (this device).
     */
    public function logout(Request $request): JsonResponse
    {
        $this->authService->logout($request->user());

        return response()->json([
            'success' => true,
            'message' => 'تم تسجيل الخروج بنجاح',
        ]);
    }

    /**
     * POST /api/auth/logout-all
     * Revokes every token for this user across all devices.
     */
    public function logoutAllDevices(Request $request): JsonResponse
    {
        $this->authService->logoutAllDevices($request->user());

        return response()->json([
            'success' => true,
            'message' => 'تم تسجيل الخروج من جميع الأجهزة',
        ]);
    }

    /**
     * GET /api/auth/me
     */
    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => new UserResource(
                $request->user()->load('roles')
            ),
        ]);
    }

    /**
     * POST /api/auth/change-password
     */
    public function changePassword(ChangePasswordRequest $request): JsonResponse
    {
        $this->authService->changePassword(
            $request->user(),
            $request->validated('password')
        );

        return response()->json([
            'success' => true,
            'message' => 'تم تغيير كلمة المرور بنجاح. تم تسجيل الخروج من الأجهزة الأخرى',
        ]);
    }

    /**
     * POST /api/auth/forgot-password
     */
    public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
    {
        $this->authService->sendPasswordResetLink($request->validated('email'));

        return response()->json([
            'success' => true,
            'message' => 'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني',
        ]);
    }

    /**
     * POST /api/auth/reset-password
     */
    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        $this->authService->resetPassword($request->validated());

        return response()->json([
            'success' => true,
            'message' => 'تم إعادة تعيين كلمة المرور بنجاح',
        ]);
    }
}