package com.dolijo.moring.car.repository;

import com.dolijo.moring.car.entity.UnauthorizedUserLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface UnauthorizedUserLogRepository extends JpaRepository<UnauthorizedUserLog, Long> {
}
