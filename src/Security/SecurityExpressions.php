<?php

namespace App\Security;

final class SecurityExpressions
{
    public const string ROLE_USER              = "is_granted('ROLE_USER')";
    public const string ROLE_STATION_INSPECTOR = "is_granted('ROLE_STATION_INSPECTOR')";
    public const string ROLE_STATION_OWNER     = "is_granted('ROLE_STATION_OWNER')";
    public const string ROLE_ADMIN             = "is_granted('ROLE_ADMIN')";
    public const string ROLE_SUPER_ADMIN       = "is_granted('ROLE_SUPER_ADMIN')";

    public const string SCHEDULE_CREATE = "is_granted('ROLE_STATION_OWNER') and is_granted('STATION_SCHEDULE_CREATE', object)";
    public const string SCHEDULE_EDIT   = "is_granted('ROLE_STATION_OWNER') and is_granted('STATION_SCHEDULE_EDIT', object)";
    public const string SCHEDULE_DELETE = "is_granted('ROLE_STATION_OWNER') and is_granted('STATION_SCHEDULE_DELETE', object)";

    public const string SCHEDULE_EXCEPTION_CREATE = "is_granted('ROLE_STATION_OWNER') and is_granted('STATION_SCHEDULE_EXCEPTION_CREATE', object)";
    public const string SCHEDULE_EXCEPTION_EDIT   = "is_granted('ROLE_STATION_OWNER') and is_granted('STATION_SCHEDULE_EXCEPTION_EDIT', object)";
    public const string SCHEDULE_EXCEPTION_DELETE = "is_granted('ROLE_STATION_OWNER') and is_granted('STATION_SCHEDULE_EXCEPTION_DELETE', object)";

    public const string USER_SELF = "is_granted('ROLE_SUPER_ADMIN') or (is_granted('ROLE_USER') and object.getId() == user.getId())";
}
