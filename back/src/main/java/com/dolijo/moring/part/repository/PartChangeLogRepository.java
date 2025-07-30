package com.dolijo.moring.part.repository;

import com.dolijo.moring.part.entity.PartChangeLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PartChangeLogRepository extends JpaRepository<PartChangeLog, Long> {
}
