<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Employee\StoreEmployeeRequest;
use App\Http\Requests\Employee\UpdateEmployeeRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\EmployeeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EmployeeController extends Controller
{
    public function __construct(protected EmployeeService $employeeService) {}

    public function index(Request $request): JsonResponse
    {
        $this->authorize('viewAny', User::class);

        $employees = $this->employeeService->paginate($request->only([
            'search', 'role', 'is_active', 'sort_by', 'sort_dir', 'per_page',
        ]));

        return $this->success([
            'items' => UserResource::collection($employees->items()),
            'pagination' => [
                'current_page' => $employees->currentPage(),
                'last_page' => $employees->lastPage(),
                'per_page' => $employees->perPage(),
                'total' => $employees->total(),
            ],
        ]);
    }

    public function store(StoreEmployeeRequest $request): JsonResponse
    {
        $employee = $this->employeeService->create($request->validated());

        return $this->success(new UserResource($employee), 'تم إضافة الموظف بنجاح', 201);
    }

    public function show(User $employee): JsonResponse
    {
        $this->authorize('view', $employee);

        return $this->success(new UserResource($employee->load('roles')));
    }

    public function update(UpdateEmployeeRequest $request, User $employee): JsonResponse
    {
        $employee = $this->employeeService->update($employee, $request->validated());

        return $this->success(new UserResource($employee), 'تم تحديث بيانات الموظف بنجاح');
    }

    public function toggleActive(User $employee): JsonResponse
    {
        $this->authorize('toggleActive', $employee);

        $employee = $this->employeeService->toggleActive($employee);

        return $this->success(new UserResource($employee), $employee->is_active ? 'تم تفعيل الموظف' : 'تم تعطيل الموظف');
    }

    public function destroy(User $employee): JsonResponse
    {
        $this->authorize('delete', $employee);

        $this->employeeService->delete($employee);

        return $this->success(message: 'تم حذف الموظف بنجاح');
    }

    public function roles(): JsonResponse
    {
        return $this->success(
            \Spatie\Permission\Models\Role::pluck('name')
        );
    }
}
